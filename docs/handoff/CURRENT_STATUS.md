# 📍 CURRENT STATUS（現在地確認）

> **Kazumax向け3行サマリー**
> - **今**: Cycle 10 / Take 5 の実装完了。PASS=49 FAIL=0。Dexのレビュー待ち。
> - **次**: Dex が `docs/handoff/P3_CC_Report/cycle_10.md` と差分をレビューし、P4を作成。
> - **Kazumaxの次アクション**: 下部の合図文を Dex にコピペして渡してください。実機の `-Watch -TestPhase2` はまだ実行しないでください。

---

このファイルは、Air・CC・Dex・Kazumaxの全員が「今どこか」「次に何を読むか」「誰が何をするか」を迷わず確認するための1ページダッシュボードです。

## 1. 現在のサイクル名とフェーズ

**Cycle 10: Maestro Runner Phase 2（CC自動起動の実装）**  
**Take 5 / CC実装完了 / Dexレビュー待ち**

## 2. 現在の担当者

**Dex (Cursor)** - Cycle 10 Take5 差分レビュー

## 3. 次に作業する担当者

**CC (Claude Code)** - Dex Take5レビュー結果に応じて対応

## 4. 今読むべきファイル一覧

Dexが次に参照すべきファイル:

- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P1_Air_Blueprint/cycle_10_maestro_phase2.md`
- `docs/handoff/P3_CC_Report/cycle_10.md`（Take5版）
- `docs/handoff/P4_Dex_Review/cycle_10_take4.md`（前回P4）
- `scripts/maestro_runner.ps1`（変更箇所: Fix1-Fix3）
- `scripts/maestro_runner.tests.ps1`（変更箇所: H7-H11）

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
- **P3 (CC Report)**: `docs/handoff/P3_CC_Report/cycle_10.md`（Take5）
- **P4 (Dex Review)**: `docs/handoff/P4_Dex_Review/cycle_10_take4.md`（前回）

## 6. 現在のStop Conditions / 禁止事項

以下はまだ禁止です。

- 実Claudeを自動起動する `-Watch -TestPhase2` 実機テスト
- 本番P1での自動起動
- `git reset --hard` / `git restore .` / `git clean` の自動実行
- 自動ロールバック
- 第3段階への進行
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作

## 7. Take 5 実装サマリー

| 修正 | 内容 | 状態 |
|------|------|------|
| Fix1 | `Invoke-Phase2IfAllowed` 共通化。PendingScan経由でもPhase2起動 | 完了 |
| Fix2 | git status失敗時PAUSE。try/catchでEAP=Stop対応 | 完了 |
| Fix3 | `--untracked-files=all` + SHA-256 hash比較。$maestroDirRel除外 | 完了 |
| H7-H11 | 外部通信なしスタブテスト追加 | PASS=49 FAIL=0 |
| バージョン | v2.1.11 → v2.1.12 | 完了 |

## 8. 各AIの作業完了時ルール（必須）

作業を終えるAIは、次担当へバトンを渡す前に必ず以下を行うこと。

1. この `CURRENT_STATUS.md` を現在地に合わせて更新する。
2. 最終チャットに「現在地サマリー」と「Kazumaxが次にコピペする合図文」を出す。
3. 合図文には、Cycle/Take、最新P1/P3/P4のパス、次担当者が読むべきファイルを含める。

## 9. このファイル自体の運用ルール

- **Single Source of Truth**: プロジェクトの現在地を示す単一の情報源として扱う。
- **履歴を積みすぎない**: 過去の詳細は各P1/P3/P4とTEAM_CHATに残し、このファイルは常に「今の瞬間」だけを示す。
- **必要時だけ読む**: AGENTS/AI_TEAM_WORKFLOW/TEAM_CHAT/proposalsは、CURRENT_STATUSや担当ルールで必要になった時だけ読む。

## 10. Kazumaxが次にコピペする合図文

```text
Dex、CCが Cycle 10 Take 5 の作業を完了したよ！
最新のファイルは以下の通り。
- P1: docs/handoff/P1_Air_Blueprint/cycle_10_maestro_phase2.md
- P3: docs/handoff/P3_CC_Report/cycle_10.md（Take5版）
- 前回P4: docs/handoff/P4_Dex_Review/cycle_10_take4.md

@.cursorrules を厳守してレビューお願い。
内容を確認して、差分レビューとQA監査を進めて！作業が終わったら CURRENT_STATUS.md を更新して、ルールのテンプレートに従って次への合図文を出してね。
```
