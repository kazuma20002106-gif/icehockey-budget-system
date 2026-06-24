# 🔄 CURRENT STATUS (現在地確認)

> **💡 Kazumax向け3行サマリー**
> - **今**: Cycle 10 / Take 4 (CC実装完了・Dexレビュー待ち)
> - **次**: Dex が Take 4 の差分レビュー(P4)を実施
> - **Kazumaxの次アクション**: ページ下部の合図文を Dex にコピペして渡してください

---

このファイルは、Air・CC・Dex・Kazumaxの全員が「今どこか」「次に何を読むか」「誰が何をするか」を迷わず確認するための1ページのダッシュボードです。

## 1. 現在のサイクル名とフェーズ
**Cycle 10: Maestro Runner Phase 2 (CC自動起動の実装)** (Take 4 / CC実装完了・Dexレビュー待ち)

## 2. 現在の担当者
👉 **Dex (Cursor)** - *Cycle 10 Take 4 の差分レビュー(P4)*

## 3. 次に作業する担当者
⏳ **CC (Claude Code)** - *DexレビューでNGが出た場合は Take 5 修正、OKなら次Cycleへ*

## 4. 今読むべきファイル一覧
Dexが現在参照すべきファイルです。
- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P1_Air_Blueprint/cycle_10_maestro_phase2.md`
- `docs/handoff/P2_Dex_Instructions/cycle_10_maestro_phase2.md`
- `docs/handoff/P3_CC_Report/cycle_10.md`
- `scripts/maestro_runner.ps1`
- `scripts/maestro_runner.tests.ps1`

### 条件付きで読むファイル
以下に1つでも当てはまる場合のみ、追加で読んでください: 新規チャット開始、1日以上の空白、Cycle/Take/担当変更、指示とCURRENT_STATUSの矛盾、Stop Conditions・外部呼び出し・課金・commit/push・自動実行・削除など安全上重要な操作、読むべきファイルに迷う場合、他AIの報告が食い違う場合。
- `AI_TEAM_WORKFLOW.md`
- `AGENTS.md`
- `.cursorrules`
- `CLAUDE.md`
- `docs/TEAM_CHAT.md`
- `docs/proposals/`

## 5. 最新のハンドオフファイル
- **P1 (Blueprint)**: `docs/handoff/P1_Air_Blueprint/cycle_10_maestro_phase2.md`
- **P2 (Dex Instructions)**: `docs/handoff/P2_Dex_Instructions/cycle_10_maestro_phase2.md`
- **P3 (CC Report)**: `docs/handoff/P3_CC_Report/cycle_10.md` ← Take 4 新規作成
- **P4 (Dex Review)**: `docs/handoff/P4_Dex_Review/cycle_10_take3.md` (Take 3 の P4)
- **Dex Safety Review**: `docs/handoff/P2_Dex_Instructions/cycle_10_take2_safety_review.md`

## 6. 現在のStop Conditions / 禁止事項
🚨 **以下の操作は初期自動化フェーズにおいて禁止されています:**
- `git commit` および `git push` の自動実行 (必ずKazumaxの目視と手動承認を挟むこと)
- Kazumaxの明示承認なしでの外部モデル・API呼び出し(課金発生操作)
- `maestro_runner.ps1` における無制限の無限ループ実行 (PAUSEファイルや履歴管理による重複実行防止を徹底すること)

## 7. 直近の未解決課題
- Dex による Cycle 10 Take 4 の差分レビュー (P4)。
- Kazumaxによる `-Watch` モードでの**ダミーP1を用いた**実機検知・CC起動テスト（Dexレビュー通過後）。
- Maestro RunnerのOneDrive依存エッジケースへの対応。

---

## 🛠️ 各AIの作業完了時ルール（必須）

AIエージェントは、自身のタスクが完了して次の担当者へバトンを渡す際、**必ず以下の2つの義務**を果たしてください。

### ① このファイル (`CURRENT_STATUS.md`) を上書き更新する
1. **Kazumax向け3行サマリー** (最上部の内容を今の状態に更新)
2. `1. 現在のサイクル名とフェーズ` (必要に応じてCycle/Take番号を更新)
3. `2. 現在の担当者` (次担当へ変更)
4. `3. 次に作業する担当者` (次の次の担当者、または待機へ変更)
5. `4. 今読むべきファイル一覧` (次担当が読むべきファイルをリストアップ)
6. `5. 最新のハンドオフファイル` (最新のP1/P3/P4ファイル名に更新)
7. `7. 直近の未解決課題` (残タスクがあれば更新)

### ② 最終チャットへ「現在地サマリー」を必ず出す
作業を終える際の最後のチャット出力には、必ず以下のテンプレートを用いて現在地サマリーとコピペ用合図文を出力してください。
**合図文には必ず「Cycle X / Take Y」と「最新のP1/P3/P4ファイルパス」を含めること。**

**【最終チャット テンプレート】**

■ 現在地サマリー
- 現在地: Cycle X / Take Y (〇〇の作業完了)
- 完了: 〇〇を実装し、P3を更新しました。
- 次: [次担当者名] による〇〇の作業
- 読むファイル: `docs/handoff/...`
- Kazumaxの次アクション: 以下の合図文を [次担当者名] にコピペして渡してください。

```text
(次担当者名)、[前担当者名]が Cycle X Take Y の作業を完了したよ！
最新のファイルは以下の通り。
- P1: docs/handoff/...
- P3: docs/handoff/...
- P4: docs/handoff/...

内容を確認して、(〇〇の作業) を進めて！作業が終わったら CURRENT_STATUS.md を更新して、ルールのテンプレートに従って次への合図文を出してね。
```

## 9. このファイル自体の運用ルール
- **Single Source of Truth**: プロジェクトの現在地を示す「唯一の情報源」として扱います。
- **作業完了時の必須タスク**: Air、CC、Dexのいずれも、自分の担当作業を終える直前に `CURRENT_STATUS.md` を書き換え、正しくバトンを繋ぐ義務を負います。
- **履歴を残さない**: このファイルは履歴を積み上げるログではありません。常に「今の瞬間」の状態だけを示すように上書きしてください。過去の履歴は各P1/P3/P4ファイルに保存されています。

## 10. Kazumaxが次にコピペする合図文

```text
Dex、CCが Cycle 10 Take 4 の作業を完了したよ！
最新のファイルは以下の通り。
- P1: docs/handoff/P1_Air_Blueprint/cycle_10_maestro_phase2.md
- P2: docs/handoff/P2_Dex_Instructions/cycle_10_maestro_phase2.md
- P3: docs/handoff/P3_CC_Report/cycle_10.md
- P4 (前回): docs/handoff/P4_Dex_Review/cycle_10_take3.md
- 現在地: docs/handoff/CURRENT_STATUS.md

@.cursorrules を厳守してレビューお願い。
内容を確認して、Take 4 の差分レビューとQA監査を進めて！作業が終わったら CURRENT_STATUS.md を更新して、ルールのテンプレートに従って次への合図文を出してね。
```
