[C12: Dex(P4) => CC(P3) Final Hardening]

# Cycle 12 最終硬化 CC向け差し戻し指示

## 目的

Cycle 12のABC機能レビューはおおむねOKです。

ただし、Dexの全体レビューで「完成品として固める前に直した方がよい最終ゲート」が残りました。CCはこのファイルと次の全体レビューを読み、最終硬化を行ってください。

必読:

- `docs/handoff/P4_Rollback/cycle_12_overall_final_review.md`
- `docs/handoff/CURRENT_STATUS.md`
- `docs/PROJECT_RULES.md`

## 対応1: 予算管理保存のサーバー側検証を強化

対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/BudgetAllocationController.java`

現状、金額の負数・非数値は保存前に止めています。一方で、POSTされた `budgetTypeIds` / `targetCategories` の組み合わせが、その年度に実在する入力対象かどうかのサーバー側検証が弱いです。

実装方針:

1. `save(...)` の保存前に、`projectMapper.findFiltered(year, null, null, null, null)` から、その年度に存在する有効な `(budgetTypeId, targetCategory)` セットを作る。
2. POSTされた各行について、次を確認する。
   - `budgetTypeId` がnullでない
   - `targetCategory` がnull/blankでない
   - `(budgetTypeId, targetCategory)` が有効セットに含まれる
   - `allocatedAmount` が負数・非数値でない
3. 不正なペアは保存せず、`/budget-allocations?year=...&error=invalid_input` へ戻す。
4. 不正な金額は従来通り `error=invalid_amount` へ戻す。

注意:

- DB schemaは変更しない。
- `ExcelExportService.java` は今回の硬化では原則触らない。
- UIだけのhidden inputに頼らず、必ずサーバー側で守る。

## 対応2: バージョン更新

Javaコードを変更するため、`src/main/resources/application.properties` の `app.version` を更新してください。

現在が `v2.4.2` なら、次は `v2.4.3` としてください。

compile後、次も確認してください。

```powershell
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

## 対応3: clean compile とresources混入確認

Dexの全体レビュー時点では、起動中Javaプロセスが `target/` を掴んでいたため、`clean compile` が失敗しました。

CCは必要に応じて、起動中のbudget-systemアプリを止めてから実行してください。

禁止:

- `git reset --hard`
- `git restore .`
- `git clean`
- 無関係なJavaプロセスの停止

検証コマンド:

```powershell
.\mvnw.cmd -q -DskipTests clean compile
```

resources混入確認:

```powershell
Get-ChildItem -Recurse target\classes\templates | Where-Object { $_.Name -match '\.(py|txt|csv|tmp|bak)$' } | Select-Object FullName
```

期待:

- 何も出ないこと
- 少なくとも `target/classes/templates/test.py` が残っていないこと

## 対応4: 未追跡ファイルの取り込み漏れ確認

Cycle 12本体の重要ファイルが未追跡のまま残っていました。

CCは作業完了報告で、少なくとも次のファイルが最終取り込み対象に含まれていることを明記してください。

```text
src/main/java/com/miyazaki/icehockey/budgetsystem/controller/BudgetAllocationController.java
src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/BudgetAllocationMapper.java
src/main/java/com/miyazaki/icehockey/budgetsystem/model/BudgetAllocation.java
src/main/resources/mapper/BudgetAllocationMapper.xml
src/main/resources/templates/budget_allocations/index.html
src/main/resources/templates/export/year_preview.html
src/main/resources/templates/export/year_setup.html
src/main/resources/schema.sql
src/main/resources/application.properties
src/main/resources/書類.xlsx
src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java
src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java
src/main/resources/templates/activity/list.html
src/main/resources/templates/layout.html
```

もしコミット作業を行う場合は、上記のCycle 12本体ファイルを落とさないでください。

## 完了条件

- `BudgetAllocationController.save(...)` で、年度内に実在しない `(budgetTypeId, targetCategory)` を保存できない
- Javaコード変更に伴い `app.version` が更新されている
- `.\mvnw.cmd -q -DskipTests clean compile` が成功している
- `target/classes/templates` に `.py/.txt/.csv/.tmp/.bak` が残っていない
- `src/main/resources` 側にも検証用ファイル混入がない
- Cycle 12本体ファイルの取り込み漏れがないことをP3報告書に明記している

## CCの報告先

作業完了後、次へP3報告書を保存してください。

```text
docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening.md
```

報告書に必ず書くこと:

- 変更したファイル
- `app.version`
- 実行した検証コマンドと結果
- resources混入確認結果
- Cycle 12本体ファイルの取り込み漏れ確認結果
- 残リスクがあれば残リスク

Kazumaxへのチャットは短く、Dexへの合図文だけで大丈夫です。
