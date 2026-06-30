# 📍 CURRENT STATUS（現在地確認）

> [!CAUTION]
> **【Kazumax代表からの全体絶対ルール】**
> 「入力が簡単になっても、合算がうまくいってなかったらツールとしては全く意味がなく、正しくない書類を作るゴミツールになってしまう。全体の数値に関する部分は絶対に間違いがあってはならない。」

> **💡 Kazumax向け3行サマリー**
> - **今**: CCがCycle10マニュアル再整理（AGENTS.md・WORKFLOW_RULES.md・PROJECT_RULES.md・CURRENT_STATUS.md）を完了し、Dex（P4）へレビュー依頼中。
> - **次**: DexがマニュアルのDIFFをレビューし、OK/NGを判定する。
> - **Kazumaxの次アクション**: 下記の合図文をDexへ渡してください。

---

## 1. 現在のサイクルとフェーズ

**Cycle 10: チームマニュアルの再整理（4層構造への再編）**
**フェーズ: CC(P3) 完了 / Dex(P4) レビュー待ち**

## 2. 現在の担当・完了待ち

完了: **CC** — マニュアル4ファイルの編集・コミット完了
待ち: **Dex** — P4レビュー（マニュアルDIFF監査）

## 3. 次に読むべきファイル（Dex向け）

- `docs/handoff/CURRENT_STATUS.md`（このファイル）
- `docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure.md`（P3報告書）
- `AGENTS.md`（編集済み）
- `docs/handoff/WORKFLOW_RULES.md`（編集済み）
- `docs/PROJECT_RULES.md`（新規作成）

## 4. 最新のハンドオフファイル

- **P1方針書**: `docs/handoff/P1_Air_Blueprint/manual_restructure_review.md`
- **P2原案**: `docs/handoff/P2_Dex_Instructions/manual_restructure_plan.md`
- **P3報告書**: `docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure.md`

## 5. 現在のStop Conditions / 禁止事項

- `git reset --hard` / `git restore .` / `git clean` の自動実行
- 自動ロールバック
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作
- Cycle 9（様式2-2-1 Excel修正）のコードタスクは現在保留中（マニュアル整備完了後に再開）

## 6. Kazumaxが次にコピーする合図文

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Dexへ：
CCがCycle10のマニュアル再整理を完了しました。
docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure.md を読んでDIFFレビュー（P4）をしてください。
```
