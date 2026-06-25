# 📍 CURRENT STATUS（現在地確認）

> **💡 Kazumax向け3行サマリー**
> - **今**: CC Cycle 8.3 Take2 修正完了（v2.2.1）。DexのNG指摘3件すべて対応済み。
> - **次**: Dex が P3 報告書を読んで再レビュー（P4）を行う。
> - **Kazumaxの次アクション**: 下部の合図文をDexへ渡してください。

---

このファイルは、Air・CC・Dex・Kazumaxの全員が「今どこか」「次に何を読むか」「誰が何をするか」を迷わず確認するための1ページダッシュボードです。

## 1. 現在のサイクル名とフェーズ

**Cycle 8.3: UI改善・Excelシート名適正化・決算書旅行雑費修正**  
**Take2 CC修正完了 / Dex再レビュー待ち**

## 2. 現在の担当者

完了: **CC** - Dex差し戻し指示 Fix1/Fix2/Fix3 をすべて修正（v2.2.1）

## 3. 次に作業する担当者

**Dex** - CC修正完了の再レビュー (P4)

## 4. 今読むべきファイル一覧

Dexが次に参照すべきファイル:

- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P3_CC_Report/cycle_8_3.md` (Take2 更新済み)
- `docs/handoff/P4_Rollback/cycle_8_3.md` (差し戻し指示)

### 条件付きで読むファイル

迷った場合、矛盾がある場合、またはルール確認が必要な場合のみ追加で読む:

- `AI_TEAM_WORKFLOW.md`
- `AGENTS.md`
- `.cursorrules`
- `CLAUDE.md`
- `docs/TEAM_CHAT.md`
- `docs/proposals/`

## 5. 最新のハンドオフファイル

- **P1/P2草案 (Air)**: `docs/handoff/P1_Air_Blueprint/cycle_8_3_draft.md`
- **P2補強版 (Dex)**: `docs/handoff/P2_Dex_to_CC/cycle_8_3.md`
- **P3 (CC Report)**: `docs/handoff/P3_CC_Report/cycle_8_3.md`（Take2 更新済み）
- **P4 (Dex Review)**: `docs/handoff/P4_Dex_Review/cycle_8_3.md`
- **P4 Rollback**: `docs/handoff/P4_Rollback/cycle_8_3.md`

## 6. Take2 修正内容サマリー

| Fix | 内容 | 状態 |
|-----|------|------|
| Fix1 | 2-2-1旅行雑費セル確認（openpyxl読み込みでR20=③旅行雑費を確定） | ✅ 確認済 |
| Fix2a | populate26 タイトルを budgetTypeId ベースへ変更 | ✅ 完了 |
| Fix2b | populate24Side タイトル "①選手強化費" 固定を budgetTypeId ベースへ変更 | ✅ 完了 |
| Fix3a | exportForm24 multi-ID をグループ化対応・新シート名適用 | ✅ 完了 |
| Fix3b | exportMultiSheet (2-5/2-6) をソート・新シート名対応 | ✅ 完了 |

コンパイル: Exit 0 / app.version=v2.2.1 確認済み

## 7. 現在のStop Conditions / 禁止事項

以下はまだ禁止です。

- Airの手順整理前に実Claudeを自動起動する `-Watch -TestPhase2` 再テスト
- 本番P1での自動起動
- `git reset --hard` / `git restore .` / `git clean` の自動実行
- 自動ロールバック
- 第3段階への進行
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作

## 8. 次回実機テスト時の注意（Cycle 10 Maestro引き継ぎ）

- `test_automation:r2` はprocessed済みなので、次回はrevisionを上げる。
- ダミーP1はmanifest投入前に必ず作る。
- P1 → SHA-256計算 → manifest作成 → `.ready.json` 配置の順序を守る。
- OneDriveの大量削除確認が出たら、必ず「保持する」を選ぶ。
- 実Claude自動起動はKazumax承認後に1ケースずつ。
- `dummy_fail:r3` はprocessed済みのため、異常系再テストは `revision: 4` 以上で行う。
- 現時点では `docs/handoff/maestro/PAUSE` が存在する。再テスト前に意図して削除すること。

## 9. 各AIの作業完了時ルール（必須）

作業を終えるAIは、次担当へバトンを渡す前に必ず以下を行うこと。

1. この `CURRENT_STATUS.md` を現在地に合わせて更新する。
2. 最終チャットに「現在地サマリー」と「Kazumaxが次にコピペする合図文」を出す。
3. 合図文には、Cycle/Take、最新P1/P3/P4のパス、次担当者が読むべきファイルを含める。

## 10. このファイル自体の運用ルール

- **Single Source of Truth**: プロジェクトの現在地を示す単一の情報源として扱う。
- **履歴を積みすぎない**: 過去の詳細は各P1/P3/P4とTEAM_CHATに残し、このファイルは常に「今の瞬間」だけを示す。
- **必要時だけ読む**: AGENTS/AI_TEAM_WORKFLOW/TEAM_CHAT/proposalsは、CURRENT_STATUSや担当ルールで必要になった時だけ読む。

## 11. Kazumaxが次にコピペする合図文

```text
Dex、CCがCycle 8.3 Take2の修正を完了したよ。

最新のファイルは以下の通り。
- P3 (CC Report): docs/handoff/P3_CC_Report/cycle_8_3.md（Take2 更新済み）
- P4 Rollback: docs/handoff/P4_Rollback/cycle_8_3.md
- 現在地: docs/handoff/CURRENT_STATUS.md

P3を読んでDIFFレビュー（P4）をして！
```
