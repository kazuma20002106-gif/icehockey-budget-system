[C12: CC(P3) => Dex(P4) Final Hardening]

# Cycle 12 最終硬化 実装完了報告

## 対応した指摘

`docs/handoff/P4_Rollback/cycle_12_final_hardening_cc_instructions.md` の対応1〜4に従い実施。

### 対応1: 予算管理保存のサーバー側検証を強化（完了）

対象: `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/BudgetAllocationController.java`

`save(...)` に、件数一致チェックの直後・金額パース前として以下を追加した。

1. `projectMapper.findFiltered(year, null, null, null, null)` からその年度の有効な `(budgetTypeId, targetCategory)` セット（`validKeys`）を構築。
2. POSTされた各行について、`budgetTypeId` が null でないか、`targetCategory` が null/blank でないか、`(budgetTypeId, targetCategory)` が `validKeys` に含まれるかを確認。
3. いずれかを満たさない行があれば保存を行わず `/budget-allocations?year=...&error=invalid_input` へリダイレクト。
4. 金額の負数・非数値チェック（`error=invalid_amount`）は既存のまま維持。

DB schema・`ExcelExportService.java` は変更していない。UI側（hidden input）はそのままで、検証はサーバー側のみで完結する。

### 対応2: バージョン更新（完了）

- `src/main/resources/application.properties` の `app.version` を `v2.4.2` → `v2.4.3` に更新。
- compile後、`src` と `target/classes` の両方で `app.version=v2.4.3` の一致を確認済み（下記検証コマンド参照）。

### 対応3: clean compileとresources混入確認（一部代替手順で完了・残課題あり）

- 起動中のJavaプロセスは確認時点で存在しなかった（`tasklist` で `java.exe` 該当なし）。
- それでも `.\mvnw.cmd -q -DskipTests clean compile` は、Dexの指摘と同様に `target\classes\...\controller` または `...\mapper` の削除失敗で複数回失敗した。原因はJavaプロセスのロックではなく、プロジェクトが OneDrive 同期フォルダ配下にあるため、`maven-clean-plugin` のディレクトリ削除中に OneDrive が一時的にファイルへアクセスし、削除が競合しているとみられる（同一フォルダを対象に再実行するたびに失敗箇所が別のサブフォルダへ移動する挙動から推測）。
- 対応として、PowerShellの `Remove-Item -Recurse -Force` で `target/` を手動削除（1回目の試行で成功）した上で、`.\mvnw.cmd -q -DskipTests compile` を実行し、ゼロから正常にビルドできることを確認した。
- 実質的に「クリーンな状態からのコンパイル成功」は達成しているが、指定コマンドそのままの `mvnw clean compile` は、このマシン・このOneDriveフォルダ配置では安定して通らない可能性がある残課題として明記する。

### 対応4: 未追跡ファイルの取り込み漏れ確認（確認完了）

指示書に記載された以下のCycle 12本体ファイルは、すべて作業ツリー上に存在することを確認した（一部は「M」＝追跡済み変更あり、一部は「??」＝未追跡）。

```text
src/main/java/com/miyazaki/icehockey/budgetsystem/controller/BudgetAllocationController.java  (??)
src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/BudgetAllocationMapper.java           (??)
src/main/java/com/miyazaki/icehockey/budgetsystem/model/BudgetAllocation.java                  (??)
src/main/resources/mapper/BudgetAllocationMapper.xml                                           (??)
src/main/resources/templates/budget_allocations/index.html                                     (??)
src/main/resources/templates/export/year_preview.html                                          (??)
src/main/resources/templates/export/year_setup.html                                            (??)
src/main/resources/schema.sql                                                                  (M)
src/main/resources/application.properties                                                      (M)
src/main/resources/書類.xlsx                                                                    (M)
src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java             (M)
src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java              (M)
src/main/resources/templates/activity/list.html                                                (M)
src/main/resources/templates/layout.html                                                       (M)
```

今回のコミットでは、上記Cycle 12本体ファイル一式＋今回変更した `BudgetAllocationController.java` ＋ `application.properties` ＋本報告書 ＋ `CURRENT_STATUS.md` のみを対象とした。

**重要（Dex/Kazumaxへの申し送り）**: `git status --short` を確認すると、上記Cycle 12関連以外にも、Cycle 8〜11のhandoffファイル・提案ファイル・`manuals/` ディレクトリ・`docs/manual_legacy/`・`.cursorrules` / `AGENTS.md` / `CLAUDE.md` / `AI_TEAM_WORKFLOW.md` / `mvnw.cmd` / `app_run_latest.pid` など、非常に多くの未追跡・変更ファイルが残っている。これらはCycle 12の範囲外であり、内容の精査（どれが最終確定版か、どれが検証用の使い捨てファイルか）が必要なため、今回のコミットには含めていない。別タスクとして棚卸しを推奨する。

## 変更したファイル

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/BudgetAllocationController.java`（`save(...)` に有効ペア検証を追加）
- `src/main/resources/application.properties`（`app.version` を `v2.4.3` に更新）

## app.version

`v2.4.3`

## 実行した検証コマンドと結果

```powershell
.\mvnw.cmd -q -DskipTests clean compile
# → maven-clean-pluginがOneDrive同期由来とみられる削除競合で複数回失敗（対応3参照）

# 代替手順
Remove-Item -Path target -Recurse -Force   # 1回目の試行で成功、target/ 完全削除を確認
.\mvnw.cmd -q -DskipTests compile
# → 成功（エラーなし）

Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
# → 両方とも app.version=v2.4.3 で一致
```

## resources混入確認結果

```powershell
Get-ChildItem -Recurse target\classes\templates | Where-Object { $_.Name -match '\.(py|txt|csv|tmp|bak)$' }
# → 該当ファイルなし（test.py 等の残留なし）
```

`src/main/resources` 側にも `.py/.txt/.csv/.tmp/.bak` の混入なし（Dexの前回確認済み事項を維持）。

## Cycle 12本体ファイルの取り込み漏れ確認結果

上記「対応4」の通り、指示書記載の14ファイルはすべて作業ツリー上に存在することを確認し、コミット対象に含めた。取り込み漏れなし。

## 残リスク

1. **`mvnw clean compile` 自体の不安定性**: OneDrive同期フォルダ配下という環境要因により、`maven-clean-plugin` の削除処理が競合で失敗することがある。手動での `target/` 削除＋`compile` は安定して成功するため、今後の検証では詰まった場合にこの代替手順を使うことを推奨する。恒久対策（例: OneDriveの当該フォルダを同期除外にする等）が必要かはKazumax判断。
2. **Cycle 8〜11 + マニュアル再編に関する大量の未追跡・未コミット差分**: 今回のコミット対象外。内容確認と棚卸しが別途必要。
3. 実DBでの本番データ出力は未実行（Dexの全体レビューから継続する残リスク）。
4. `projects.target_category` はDB上nullableのままであり、古い直接投入データや未知種別がある場合は2-3固定行に載らない可能性がある（Dexの全体レビューから継続する残リスク）。

## 次への合図

```text
CCがCycle 12最終硬化（予算保存検証強化・バージョン更新・clean compile代替検証・未追跡ファイル取り込み確認）を完了しました。
docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening.md を読んで、事後レビュー（P4）をお願いします。
```
