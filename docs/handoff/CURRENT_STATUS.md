# 📍 CURRENT STATUS（現在地確認）

> **💡 Kazumax向け3行サマリー**
> - **今**: Cycle 10 実機診断対応の小修正をCCが完了。done.json契約をプロンプトに明記。PASS=54 FAIL=0。
> - **次**: Dex が差分レビューし、問題なければ Air が成功系・失敗系を分けた実機手順を整理。
> - **Kazumaxの次アクション**: 下部の合図文を Dex に渡してください。まだ `-Watch -TestPhase2` は再実行しないでください。

---

このファイルは、Air・CC・Dex・Kazumaxの全員が「今どこか」「次に何を読むか」「誰が何をするか」を迷わず確認するための1ページダッシュボードです。

## 1. 現在のサイクル名とフェーズ

**Cycle 10: Maestro Runner Phase 2（CC自動起動の稼働）**  
**Live Test Diagnosis 対応 / CC小修正完了 / Dexレビュー待ち**

## 2. 現在の担当者

**Dex (Cursor)** - CC小修正の差分レビュー

## 3. 次に作業する担当者

**Air (Gemini)** - Dexレビュー後、成功系・失敗系を分けた実機手順の整理

## 4. 今読むべきファイル一覧

Dexが次に参照すべきファイル:

- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P4_Dex_Review/cycle_10_live_test_diagnosis.md`
- `docs/handoff/P3_CC_Report/cycle_10.md`（実機診断対応版）
- `scripts/maestro_runner.ps1`（変更箇所: プロンプト生成部・ブロック順序）
- `scripts/maestro_runner.tests.ps1`（変更箇所: H14追加）

### 条件付きで読むファイル

迷った場合、矛盾がある場合、またはルール確認が必要な場合のみ追加で読む:

- `AI_TEAM_WORKFLOW.md`
- `AGENTS.md`
- `.cursorrules`
- `CLAUDE.md`
- `docs/TEAM_CHAT.md`
- `docs/proposals/`

## 5. 最新のハンドオフファイル

- **P1 (Blueprint)**: `docs/handoff/P1_Air_Blueprint/cycle_10_maestro_phase2.md`
- **P2 (Dex Instructions)**: `docs/handoff/P2_Dex_Instructions/cycle_10_maestro_phase2.md`
- **P3 (CC Report)**: `docs/handoff/P3_CC_Report/cycle_10.md`（実機診断対応・v2.1.14）
- **Dex診断**: `docs/handoff/P4_Dex_Review/cycle_10_live_test_diagnosis.md`
- **前回P4**: `docs/handoff/P4_Dex_Review/cycle_10_take6.md`

## 6. 現在のStop Conditions / 禁止事項

以下はまだ禁止です。

- Dexレビュー前に実Claudeを自動起動する `-Watch -TestPhase2` 再テスト
- 本番P1での自動起動
- `git reset --hard` / `git restore .` / `git clean` の自動実行
- 自動ロールバック
- 第3段階への進行
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作

## 7. 今回の修正サマリー（実機診断対応）

| 項目 | 内容 | 状態 |
|------|------|------|
| done.json契約 | `revision`数値厳密一致・`result="success"`・禁止例・P1ハッシュ事前埋め込み・JSONテンプレ同梱 | 完了 |
| 処理順序是正 | git安全監査 → P1存在チェック → P1ハッシュ計算/プロンプト生成 | 完了 |
| H14 | プロンプト契約検証テスト追加（revision=2 実機再現） | PASS |
| バージョン | v2.1.13 → v2.1.14 | 完了 |
| 全テスト | PASS=54 FAIL=0 | 確認済 |

## 8. 次回実機テスト時の注意

- `test_automation:r2` はprocessed済み → revision を上げること。
- ダミーP1（`dummy_success.md`等）はmanifest投入の**前**に作成（P1→SHA-256→manifest→.ready.json順）。
- 実Claude自動起動は Kazumax 承認後に1ケースずつ。

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
Dex、CCが Cycle 10 実機診断の小修正を完了したよ！
最新のファイルは以下の通り。
- P1: docs/handoff/P1_Air_Blueprint/cycle_10_maestro_phase2.md
- P3: docs/handoff/P3_CC_Report/cycle_10.md（実機診断対応版）
- Dex診断: docs/handoff/P4_Dex_Review/cycle_10_live_test_diagnosis.md

@.cursorrules を厳守してレビューお願い。
done.json契約のプロンプト明記とブロック順序の差分を確認して、QA監査を進めて！作業が終わったら CURRENT_STATUS.md を更新して、ルールのテンプレートに従って次への合図文を出してね。
```
