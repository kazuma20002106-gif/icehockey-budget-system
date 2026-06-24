# 📍 CURRENT STATUS（現在地確認）

> **💡 Kazumax向け3行サマリー**
> - **今**: AI自動化システム（Maestro Runner）の開発はCycle 10で一旦保留し、本来の「ツール（Budget System）作り」に回帰。
> - **結果**: 自動化の再開用スナップショットとして `docs/handoff/MAESTRO_RUNNER_PARKED_STATE.md` を作成。
> - **Kazumaxの次アクション**: ツール（Budget System）のどの機能の実装・修正から着手するか、要件をAirへ指示してください。

---

このファイルは、Air・CC・Dex・Kazumaxの全員が「今どこか」「次に何を読むか」「誰が何をするか」を迷わず確認するための1ページダッシュボードです。

## 1. 現在のサイクル名とフェーズ

**本来のツール開発（Budget System）へ回帰**  
※ AI自動化機能は `MAESTRO_RUNNER_PARKED_STATE.md` に状態を保存して一時保留（Park）中

## 2. 現在の担当者

**Kazumax** - 開発再開するツールの要件・ターゲットの指示

## 3. 次に作業する担当者

**Air / Dex** - Kazumaxの指示を受け、ツール開発の計画・実装を開始する

## 4. 今読むべきファイル一覧

Airが次に参照すべきファイル:

- `docs/handoff/P1_Air_Blueprint/cycle_10_live_test_procedure.md`
- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P4_Dex_Review/cycle_10_live_test_diagnosis.md`
- `docs/handoff/P4_Dex_Review/cycle_10_live_diagnosis_fix_review.md`
- `docs/handoff/P3_CC_Report/cycle_10.md`
- `scripts/maestro_runner.ps1`

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
- **Dexレビュー**: `docs/handoff/P4_Dex_Review/cycle_10_live_diagnosis_fix_review.md`
- **Dex異常系結果**: `docs/handoff/P4_Dex_Review/cycle_10_live_test_abnormal_only_result.md`

## 6. 現在のStop Conditions / 禁止事項

以下はまだ禁止です。

- Airの手順整理前に実Claudeを自動起動する `-Watch -TestPhase2` 再テスト
- 本番P1での自動起動
- `git reset --hard` / `git restore .` / `git clean` の自動実行
- 自動ロールバック
- 第3段階への進行
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作

## 7. Dexレビュー結果

- `scripts/maestro_runner.ps1` parser OK
- `scripts/maestro_runner.tests.ps1` parser OK
- 外部通信なし統合テスト `PASS=54 FAIL=0`
- `revision` 数値厳密一致、`result="success"` 固定、禁止例、JSONテンプレートをプロンプトに明記済み
- H14で `revision=2` 実機異常の再発防止を検証済み

## 8. 次回実機テスト時の注意

- `test_automation:r2` はprocessed済みなので、次回はrevisionを上げる。
- ダミーP1はmanifest投入前に必ず作る。
- P1 → SHA-256計算 → manifest作成 → `.ready.json` 配置の順序を守る。
- OneDriveの大量削除確認が出たら、必ず「保持する」を選ぶ。
- 実Claude自動起動はKazumax承認後に1ケースずつ。
- `dummy_fail:r3` はprocessed済みのため、異常系再テストは `revision: 4` 以上で行う。
- 現時点では `docs/handoff/maestro/PAUSE` が存在する。再テスト前に意図して削除すること。
- 今回のPAUSE原因は `CC呼び出し60秒タイムアウト`。`automation_fail.txt` と `cc.done.json` は生成されていない。

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
Air、異常系(r4)と正常系(r4)の実機テストが両方とも大成功したよ！
PAUSEの発動（不正差分検知）も、正常系の完走も完璧だった！

最新のファイルは以下の通り。
- 手順書: docs/handoff/P1_Air_Blueprint/cycle_10_live_test_procedure.md
- 現在地: docs/handoff/CURRENT_STATUS.md

これでCycle 10のテストは完全クリアだね！
P3/P4やCURRENT_STATUS.mdを整理して、次のCycle 11（第3段階：自律ループと検証）の計画を立てて、合図文を出してね。
```
