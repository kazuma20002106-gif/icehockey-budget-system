[C12: Dex(P4) => Kazumax / CC(P3) Overall]

# Cycle 12 年度末決算ファイル一括出力 全体レビュー

## 判定

**機能レビュー: おおむねOK**

**最終ゲート: NG / 取り込み・硬化対応が必要**

12A/12B/12CそれぞれのP4レビューではOKでした。今回あらためてCycle 12全体を横断レビューした結果、金額集計・Excelセル座標・UI条件保持そのものには新たなP1/P2級の機能バグは見つかりませんでした。

ただし、最終運用・保存・共有の観点で次の指摘があります。特に未追跡ファイルは、今後コミットやバックアップ、別AIへの引き継ぎで落とすとCycle 12が壊れるため、最終ゲートとして止めます。

## サブレビュー利用判断

**使用しました。**

理由: Cycle 12全体は金額・Excel・DB・UI条件保持がすべて絡むため、Dex単独では観点が多すぎます。デクスクルーを3系統に分けて並行確認しました。

- デクスクルーA: 金額・Excel出力・セル座標・帳票集計
- デクスクルーB: UI導線・検索条件保持・hidden input・画面遷移
- デクスクルーC: DB/schema/mapper/保存処理/バージョン/未追跡ファイル混入

統合判断:

- A/Bの機能観点はOKとして採用
- Cの未追跡ファイル指摘はP1として採用
- Cの保存値検証指摘はP2として採用
- Cのresources混在指摘はP3として採用

## Findings

### P1: Cycle 12本体ファイルに未追跡ファイルが残っている

`git status --short` で、Cycle 12の本体実装ファイルが未追跡です。

```text
?? src/main/java/com/miyazaki/icehockey/budgetsystem/controller/BudgetAllocationController.java
?? src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/BudgetAllocationMapper.java
?? src/main/java/com/miyazaki/icehockey/budgetsystem/model/BudgetAllocation.java
?? src/main/resources/mapper/BudgetAllocationMapper.xml
?? src/main/resources/templates/budget_allocations/index.html
?? src/main/resources/templates/export/year_preview.html
?? src/main/resources/templates/export/year_setup.html
```

影響:

- `ExcelExportService.java` は `BudgetAllocationMapper` / `BudgetAllocation` に依存している
- `layout.html` は `/budget-allocations` へリンクしている
- 未追跡ファイルを落とした状態でコミット・共有・復元すると、ビルド欠落または導線404になる

対応:

- Cycle 12を最終保存・コミット・別AIへ共有する前に、上記ファイルを必ず取り込み対象に含める
- 「どのファイルがCycle 12本体か」をP3/P4の最終メモに明示する

### P2: 予算管理保存でtargetCategoryのサーバー側検証が弱い

対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/BudgetAllocationController.java`
- `save(...)`

現状:

- 件数一致と金額の不正値・負数は保存前に止めている
- ただし `targetCategories` の空文字、任意文字列、年度内に実在しない `(budgetTypeId, targetCategory)` ペアをサーバー側で再検証していない

通常UI操作では hidden input なので問題化しにくいです。しかし、不正POSTや手動改変で空カテゴリ・無関係カテゴリの内示額を保存できます。

影響:

- `budget_allocations` に本来UI上存在しない組み合わせが保存される可能性がある
- 様式2-3のプレビュー・出力に余計な行が出る、または固定行探索で例外停止する可能性がある

対応:

- `save(...)` の前に、その年度の `projectMapper.findFiltered(year, null, null, null, null)` から有効な `(budgetTypeId, targetCategory)` セットを作る
- POSTされた各ペアが有効セットに含まれるか確認する
- `targetCategory` が空またはblankなら保存拒否する

### P3: clean compileがJavaプロセスのtargetロックで未完了

通常compileは成功しました。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

ただし、PROJECT_RULESのresources混入対策として実行した `clean compile` は、起動中Javaプロセスが `target/classes/.../controller` を掴んでいたため失敗しました。

```text
Failed to clean project: Failed to delete ...\target\classes\com\miyazaki\icehockey\budgetsystem\controller
```

また、現時点の `target/classes/templates` には古い生成物が残っています。

```text
target/classes/templates/test.py
```

確認済み:

- `src/main/resources` 側には `.py/.txt/.csv/.tmp/.bak` の混入なし
- 通常compile後、`app.version` は `src` / `target` とも `v2.4.2`

対応:

- 起動中のJavaアプリを停止する
- `.\mvnw.cmd -q -DskipTests clean compile` を再実行する
- `target/classes/templates` に `.py/.txt/.csv/.tmp/.bak` が残っていないことを確認する

## OK確認

### 金額・Excel

- preview/download は同じ `buildAnnualClosingWorkbook(...)` 系で集計する
- `workbook.setForceFormulaRecalculation(true)` あり
- 金額集計は `long` を使用し、Excel書込時も `(double) long` で書く
- 2-1の主要セルは `AC3/AG3/AK3`, `AB9/AI9/AB11`, `E15`, `AA42/AA43` に書き込む
- 2-2-1×3のJ列座標は指示書と一致
- 選手強化費2-2-1の女性側内訳は `AF` 列へ書き、`AL` の単位セルを壊さない
- トップチームの旅行雑費・駐車料金、ふるさとの借用料・駐車料金・報償費は、欄がないためデータがある場合に例外停止する
- 様式2-3はK/T/AC列を使い、トップチームは原本に正式行がないため自動書込しない

### テンプレートExcel

`src/main/resources/書類.xlsx` をZIP/XMLとして確認しました。

- 主要シート名はコードの固定名と一致
- `externalLinks` エントリなし
- XML内に `192.168.145.12` / `R6 トップ` / 外部参照らしき文字列なし
- 以前危険だった `様式２－２!AE17/AE19/AE21/J27` は、現在は2-2-1参照またはSUM式に修正済み

### UI導線

- 活動一覧から `/export/year/setup` へ `year / budgetTypeId / month / targetCategory / projectName` を渡す
- setup 画面で同じ条件を表示・POSTする
- preview controller と download controller は同じ `findFiltered(...)` 条件を使う
- 「条件を編集」リンクは絞り込み条件と提出情報を保持する
- download hidden input に絞り込み条件と提出情報が揃っている

### DB/schema

- `budget_allocations` は `CREATE TABLE IF NOT EXISTS`
- `DROP` なし
- `allocated_amount` は `BIGINT`
- 一意キー `(fiscal_year, budget_type_id, target_category)` と `ON DUPLICATE KEY UPDATE` で保存
- 負数・非数値金額は保存前に拒否

## 残リスク

- 実DBでの本番データ出力は未実行
- 旧直リンク `/activity/export/annual` は提出情報入力なしの互換経路として残っている。運用では新導線「年度末決算ファイル出力」を使うのが安全
- `projects.target_category` はDB上nullableなので、古い直接投入データや未知種別がある場合、2-3固定行に載らない可能性がある

## 次の対応案

**CC(P3)推奨**:

1. `BudgetAllocationController.save(...)` に有効ペア検証を追加する
2. 起動中Javaプロセスを停止した状態で `clean compile` を通す
3. `target/classes/templates` の混入が消えたことを確認する
4. Cycle 12本体ファイルが未追跡のまま残らないよう、最終取り込み対象を明示する

## Kazumax向け短縮版

中身の機能はかなり良いところまで来ています。

ただし、最後に「保存・共有するときに落としたら壊れる未追跡ファイル」と「clean compile未完了」が残っています。ここは帳票の中身というより、完成品として固める前の荷造りチェックです。

CCへ軽い最終硬化を頼むのが安全です。
