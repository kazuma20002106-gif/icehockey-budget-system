[C12: Dex(P4) => CC(P3) Final Hardening Take2]

# Cycle 12 最終硬化 P4事後レビュー

## 判定

**NG / Take2差し戻し**

予算保存検証強化そのものは、指示通り入っています。

ただし、`v2.4.3` としてpush済みの状態がまだ自己完結していません。主に「CURRENT_STATUSが参照しているCycle 12のhandoffファイルが未追跡のまま」「CC報告でコミット対象とされたActivityControllerのCycle 12差分が未コミット」という2点が残っています。

## サブレビュー利用判断

**使用しました。**

理由: DB保存検証と、push済み成果物の取り込み/ビルド確認は別観点の最終ゲートなので、デクスクルーA/Bで並行確認しました。

- デクスクルーA: `BudgetAllocationController.save(...)` の保存検証
- デクスクルーB: `v2.4.3` コミット、ビルド成果物、resources混入、未追跡ファイル

統合判断:

- 保存検証の機能修正はOK
- push済み成果物の自己完結性に問題があるため、最終P4はNG

## Findings

### P2: `CURRENT_STATUS.md` が参照するCycle 12 handoffファイルの大半が未追跡で、push済みHEADに含まれていない

`HEAD` に含まれるCycle 12系handoffは、現時点で次の3件のみです。

```text
docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening.md
docs/handoff/P4_Rollback/cycle_12_final_hardening_cc_instructions.md
docs/handoff/P4_Rollback/cycle_12_overall_final_review.md
```

一方、`docs/handoff/CURRENT_STATUS.md` は次のような多数のCycle 12ファイルを「読むべきファイル」として参照していますが、これらは未追跡のままです。

```text
?? docs/handoff/P1_Air_Blueprint/cycle_12_annual_export_draft.md
?? docs/handoff/P1_Air_Blueprint/cycle_12_annual_export_take2.md
?? docs/handoff/P1_Air_Blueprint/cycle_12b_12c_planning.md
?? docs/handoff/P2_Dex_to_CC/cycle_12_annual_export_pre_audit.md
?? docs/handoff/P2_Dex_to_CC/cycle_12_annual_export_take2_final_instructions.md
?? docs/handoff/P2_Dex_to_CC/cycle_12_original_formula_audit.md
?? docs/handoff/P2_Dex_to_CC/cycle_12b_budget_allocations_form23_instructions.md
?? docs/handoff/P2_Dex_to_CC/cycle_12c_preview_ui_instructions.md
?? docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a.md
?? docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a_take2.md
?? docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a_take3.md
?? docs/handoff/P3_CC_to_Dex/cycle_12b_budget_allocations_form23.md
?? docs/handoff/P3_CC_to_Dex/cycle_12b_budget_allocations_form23_take2.md
?? docs/handoff/P3_CC_to_Dex/cycle_12c_preview_ui.md
?? docs/handoff/P3_CC_to_Dex/cycle_12c_preview_ui_take2.md
?? docs/handoff/P4_Dex_Review/cycle_12_annual_export_12a_take3.md
?? docs/handoff/P4_Dex_Review/cycle_12b_budget_allocations_form23_take2.md
?? docs/handoff/P4_Dex_Review/cycle_12c_preview_ui_take2.md
?? docs/handoff/P4_Rollback/cycle_12_annual_export_12a.md
?? docs/handoff/P4_Rollback/cycle_12_annual_export_12a_take2.md
?? docs/handoff/P4_Rollback/cycle_12b_budget_allocations_form23.md
?? docs/handoff/P4_Rollback/cycle_12c_preview_ui.md
?? docs/proposals/CC_cycle_12_template_slim.md
?? docs/proposals/CC_cycle_12b_dev_launch_config.md
?? docs/proposals/Dex_cycle_12_annual_export_split.md
```

影響:

- 別チャット、別AI、またはclean checkoutで `CURRENT_STATUS.md` を読むと、読むべきファイルが見つからない
- 「push済みv2.4.3だけでCycle 12の経緯を追える」状態になっていない
- マニュアル運用上のhandoffルールに反する

対応:

- `CURRENT_STATUS.md` が参照するCycle 12 handoff/proposalsを、必要なものだけコミット対象に含める
- もし一部を意図的に含めないなら、`CURRENT_STATUS.md` の読むべきファイル一覧から外す
- 最低限、Cycle 12のP1/P2/P3/P4の判断根拠として現在地に列挙しているファイルは、push済みHEADで読める状態にしてください

### P2: `ActivityController.java` にCycle 12Aの未コミット差分が残っており、CC報告の「取り込み漏れなし」と一致しない

現在の作業ツリーには、`src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java` の未コミット差分があります。

差分内容は、Cycle 12A由来の直接ダウンロードエンドポイントです。

```java
@GetMapping("/export/annual")
public void exportAnnual(...)
```

一方、CCのP3報告では `ActivityController.java (M)` をCycle 12本体として「今回のコミット対象に含めた」と説明しています。しかし、`git show --name-status HEAD` では `ActivityController.java` は `v2.4.3` コミットに含まれていません。

影響:

- 報告と実際のpush済みHEADが一致していない
- 現在の `target/classes` は、未コミットの `ActivityController.java` を含んだdirty worktreeでcompileされた可能性がある
- `v2.4.3` コミット単体のビルド成果物とは断定しづらい

補足:

- 現在の新UI導線は `/export/year/setup` なので、アプリの主要導線は動く見込みです
- ただし、Cycle 12A/12Cのhandoffでは `/activity/export/annual` を「既存互換ルートとして残す」と何度も記録しています
- 残す方針ならコミットに含める、不要ならhandoff/CURRENT_STATUSから「残っている」前提を消す必要があります

対応:

- `ActivityController.java` の未コミット差分をどう扱うか決める
- 残すならコミットに含め、再compileする
- 不要なら、CURRENT_STATUSや関連handoffで「旧直リンクは運用対象外」と明記する
- どちらの場合も、P3報告の「取り込み漏れなし」と一致する状態にしてください

### P3: 不正POSTの型変換エラーは `invalid_input` リダイレクトに揃わない

対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/BudgetAllocationController.java`

`save(...)` は `year` を `int`、`budgetTypeIds` を `List<Integer>` で受けています。

そのため、例えば `year=abc` や `budgetTypeIds=abc` のような不正POSTは、Springの型変換で `save(...)` 本体に入る前に弾かれます。この場合、今回追加した `invalid_input` リダイレクトには入りません。

影響:

- 不正データ保存は防げるため、P1/P2ではありません
- ただし、指示書の「不正なペアは `/budget-allocations?year=...&error=invalid_input` へ戻す」と完全には揃いません

対応:

- 今回必須ではありません
- 将来、エラー表示を完全統一したい場合は `String` / `List<String>` で受けて自前parseしてください

## OK確認

### 保存検証

`BudgetAllocationController.save(...)` では、件数一致チェック後、保存前に次を確認しています。

- その年度の `projectMapper.findFiltered(year, null, null, null, null)` から有効な `(budgetTypeId, targetCategory)` を作る
- `budgetTypeId` がnullでない
- `targetCategory` がnull/blankでない
- `(budgetTypeId, targetCategory)` が有効セットに含まれる
- 金額の負数・非数値は保存前に `invalid_amount` で止める

通常UIからの保存、およびhidden input改ざんによる無関係カテゴリ保存の防止は満たしています。

### バージョン・compile・resources混入

Dex側でも以下を実行し、成功しました。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

初回はサンドボックス内のネットワーク制限でMaven Centralへ到達できず失敗しましたが、外部通信許可つきで同じcompileを再実行し、成功を確認しました。

`app.version` は一致しています。

```text
src/main/resources/application.properties: app.version=v2.4.3
target/classes/application.properties: app.version=v2.4.3
```

`target/classes/templates` に `.py/.txt/.csv/.tmp/.bak` は残っていません。

## 次の担当

**CC(P3) Take2**:

1. `CURRENT_STATUS.md` が参照するCycle 12 handoff/proposalsを、push済みHEADで読めるようにしてください。
2. `ActivityController.java` の未コミットCycle 12差分を、残す/残さないの方針に合わせて整理してください。
3. 整理後、`.\mvnw.cmd -q -DskipTests compile` を実行し、`app.version=v2.4.3` の同期とresources混入なしを再確認してください。
4. `docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening_take2.md` に報告してください。

