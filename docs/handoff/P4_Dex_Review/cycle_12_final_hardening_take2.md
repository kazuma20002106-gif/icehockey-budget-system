[C12: Dex(P4) => Kazumax Final Check]

# Cycle 12 最終硬化 Take2 P4再レビュー

## 判定

**OK / Kazumax最終確認へ進行可**

CCのTake2修正により、前回P4で差し戻した2点は解消されました。

- `CURRENT_STATUS.md` が参照するCycle 12 handoff/proposalsは、実ファイルとして存在し、push済みHEADから読める
- `ActivityController.java` のCycle 12A互換ルート `/activity/export/annual` は、残す方針どおりHEADに取り込まれている
- Cycle 12関連の未コミット差分・未追跡残りは検出されない
- compile、`app.version=v2.4.3`、resources混入チェックはOK

## サブレビュー利用判断

**使用しました。**

理由: Cycle 12の最終ゲートであり、handoff自己完結性とコード/ビルド整合性を分けて確認した方が安全なため。

- デクスクルーA: `CURRENT_STATUS.md` が参照するCycle 12 handoff/proposalsの存在・HEAD取り込み・未追跡残りを確認
- デクスクルーB: `ActivityController.java`、Cycle 12関連差分、compile、version、resources混入を確認

Dex統合判断:

- デクスクルーA/BともにP1/P2/P3指摘なし
- Dex側の実測結果とも一致
- 前回NG理由は解消済みとして、P4 OK判定

## 確認したHEAD

```text
c1db501 (HEAD -> main, origin/main) [v2.4.3] Cycle 12 最終硬化 Take2: handoff自己完結性とActivityController整理
```

## Findings

**P1/P2/P3指摘なし。**

補足レベル:

- worktree全体にはCycle 8〜11、マニュアル再編、dummy系などスコープ外の未コミット/未追跡ファイルが残っています。
- ただし、今回のCycle 12最終硬化Take2対象であるCycle 12 handoff/proposals、ActivityController、Cycle 12本体コード、resources、versionには未反映差分はありません。
- スコープ外の棚卸しは、Cycle 12完了後の別タスクで扱うのが安全です。

## OK確認

### 1. handoff/proposals自己完結性

`docs/handoff/CURRENT_STATUS.md` の「読むべきファイル」に含まれるCycle 12関連ファイルは、すべて実ファイルとして存在し、HEADから読めることを確認しました。

確認対象例:

- `docs/handoff/P1_Air_Blueprint/cycle_12b_12c_planning.md`
- `docs/handoff/P2_Dex_to_CC/cycle_12_annual_export_take2_final_instructions.md`
- `docs/handoff/P2_Dex_to_CC/cycle_12b_budget_allocations_form23_instructions.md`
- `docs/handoff/P2_Dex_to_CC/cycle_12c_preview_ui_instructions.md`
- `docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening_take2.md`
- `docs/handoff/P4_Rollback/cycle_12_final_hardening.md`
- `docs/proposals/CC_cycle_12_template_slim.md`
- `docs/proposals/CC_cycle_12b_dev_launch_config.md`
- `docs/proposals/Dex_cycle_12_annual_export_split.md`

Take2報告に記載された `cycle_12_annual_export_draft.md` / `cycle_12_annual_export_take2.md` も、CURRENT_STATUS上の最優先リスト外ではありますが、実ファイル・HEAD取り込み済みでした。

### 2. ActivityController整理

`src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java` はHEADに含まれており、Cycle 12A互換ルートが存在します。

```java
@GetMapping("/export/annual")
public void exportAnnual(...)
```

このルートは `/activity/export/annual` として機能し、対象事業0件時は出力を止めて `/activity?year=...&error=no_data_for_annual_export` へ戻す実装になっています。

`ExcelExportService.exportAnnualClosingBook(...)` への依存もHEAD側に存在し、compileで解決済みです。

### 3. Cycle 12関連の未コミット残り

以下の観点で未コミット・未追跡残りなしを確認しました。

- `cycle_12*`
- `CC_cycle_12*`
- `Dex_cycle_12*`
- `ActivityController`
- `BudgetAllocation`
- `ExcelExportService`
- `ExportController`
- `schema.sql`
- `application.properties`
- `書類.xlsx`
- `budget_allocations`
- `year_preview`
- `year_setup`

`git diff --name-only HEAD -- src/main/java src/main/resources` も空でした。

### 4. compile / version / resources

通常実行はサンドボックス内ネットワーク制限でMaven Centralへ到達できず失敗しましたが、外部通信許可つきで同じcompileを再実行し、成功しました。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

`app.version` は同期済みです。

```text
src/main/resources/application.properties: app.version=v2.4.3
target/classes/application.properties: app.version=v2.4.3
```

`target/classes/templates` に `.py/.txt/.csv/.tmp/.bak` の混入はありません。

## 残リスク

1. 実DB・本番データでの年度末Excel出力は未実行です。
2. `projects.target_category` はDB上nullableのままです。
3. 不正POSTの型変換エラーは、全ケースが `invalid_input` へ統一されるわけではありません。ただし不正保存は防げています。
4. Cycle 8〜11やマニュアル再編系の未追跡/未コミット整理は、Cycle 12とは別タスクで棚卸ししてください。

## Kazumax最終確認チェックリスト

1. 年度末出力画面から、年度・条件を選んでプレビューが表示されること。
2. プレビューのタブで様式2-1 / 2-2 / 2-2-1 / 2-3 / 2-4 / 2-5 / 2-6相当の内容を確認できること。
3. 提出日・団体名・代表者名を入力してExcel出力できること。
4. 出力Excelの金額合算が、画面で入力した事業・予算内示・活動実績と大きくズレていないこと。
5. 予算管理画面で、不正な年度/カテゴリの保存が通常操作では起きないこと。
6. 旧互換ルート `/activity/export/annual` を使う必要がある場合、0件時に出力を止めること。

## 次の担当

**Kazumax最終確認。**

実機で上記チェックリストを確認し、問題なければCycle 12完了として次サイクルへ進めます。
