# CURRENT STATUS

> [!CAUTION]
> **Kazumax代表からの全体絶対ルール**
> 入力が簡単になっても、合算が正しくなければツールとして意味がない。合算が正常に行われているかを第一優先にする。

## Current Cycle

- Cycle 17: UX改善（一括処理・印刷ステータス絞り込み・活動複製・ダッシュボード）

## 現在地

- Air(P1): Blueprint作成完了
- Dex(P2): 事前監査完了。CC(P3)向け最終指示書を作成済み
- CC(P3): 実装・実機検証・compile確認完了。`docs/handoff/P3_CC_to_Dex/cycle_17_ux_improvements.md` に報告書を保存済み

## 次担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_17_ux_improvements.md` を読んでDIFFレビューする

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/AI_TEAM_WORKFLOW.md`
3. `manuals/WORKFLOW_RULES.md`
4. `docs/PROJECT_RULES.md`
5. `docs/handoff/WORKFLOW_RULES.md`
6. `docs/handoff/P1_Air_Blueprint/cycle_17_ux_improvements.md`
7. `docs/handoff/P2_Dex_to_CC/cycle_17_ux_improvements_instructions.md`

## Cycle 17 重要ルール

- legacy `/export` は削除しない。直接URLと既存preview/downloadを維持する
- 印刷ステータスは「未印刷/印刷済」の手動管理。Excel出力で自動変更しない
- `/activity` とダッシュボードの金額は「決算書計上額」基準。個人雑費は含めず、旅行雑費は含める
- 活動複製は入力ひな形目的。金額項目をコピーせず、二重計上を防ぐ
- 一括削除はPOST・未選択ガード・確認ダイアログ必須
- `app.version` は v2.4.9 へ更新し、compile後に `target/classes/application.properties` と同期確認する

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行は禁止
- `git add .` の自動実行は禁止
- 作業中の他AI/ユーザー差分を勝手に戻さない
- 金額計算、Excel出力、DB、mapper、schemaに触る変更は、Air(P1) -> Dex(P2) -> CC(P3) -> Dex(P4) の完全プロセスを通す
- 個人雑費 `miscellaneousCost` と旅行雑費 `travelMiscCost` を混同しない
- 2-2集計に個人雑費 `miscellaneousCost` を追加しない

## 履歴アーカイブ

- 古い進捗・過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` を参照
- 各サイクルの正式記録は `docs/handoff/P1_Air_Blueprint/`, `docs/handoff/P2_Dex_to_CC/`, `docs/handoff/P3_CC_to_Dex/`, `docs/handoff/P4_Dex_Review/`, `docs/handoff/P4_Rollback/` に保存済み
