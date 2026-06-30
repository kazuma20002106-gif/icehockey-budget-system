# 📍 CURRENT STATUS（現在地確認）

> [!CAUTION]
> **【Kazumax代表からの全体絶対ルール】**
> 「入力が簡単になっても、合算がうまくいってなかったらツールとしては全く意味がなく、正しくない書類を作るゴミツールになってしまう。全体の数値に関する部分は絶対に間違いがあってはならない。その点を踏まえて実装すること！」

> **💡 Kazumax向け3行サマリー**
> - **今**: CCのTake3修正が完了（v2.3.6）し、Dex（P4）へ再提出済み。
> - **次**: DexがP4レビューを行い、OK/NGを判定する。
> - **Kazumaxの次アクション**: 下記の合図文をDexへ渡してください。

---

このファイルは、Air・CC・Dex・Kazumaxの全員が「今どこか」「次に何を読むか」「誰が何をするか」を迷わず確認するための1ページダッシュボードです。

## 1. 現在のサイクル名とフェーズ

**Cycle 9: 様式2-2-1（選手強化）Excel出力の金額計算ロジック修正（Take3 P4レビュー待ち）**  
**フェーズ: CC(P3) Take3 完了 / Dex(P4) レビュー待ち**

## 2. 現在の担当・完了待ち
完了: **CC** - Take3修正・コンパイル・コミット・push完了（v2.3.6）

## 3. 次に作業する担当

**Dex** - P4レビュー（差し戻し全5項目の対応確認）

## 4. 今読むべきファイル一覧

Dexが次に参照すべきファイル:

- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take3.md`
- `docs/handoff/P4_Rollback/cycle_9_post_review.md`
- `docs/handoff/P4_Dex_Review/cycle_9_post_review.md`

### 条件付きで読むファイル

迷った場合、矛盾がある場合、またはルール確認が必要な場合のみ追加で読む:

- `AI_TEAM_WORKFLOW.md`
- `AGENTS.md`
- `.cursorrules`
- `CLAUDE.md`
- `docs/TEAM_CHAT.md`
- `docs/proposals/`

## 5. 最新のハンドオフファイル

- **P2実装指示書**: `docs/handoff/P2_Dex_to_CC/cycle_9.md`
- **P3報告書(Take3)**: `docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take3.md`
- **P4事後レビュー**: `docs/handoff/P4_Dex_Review/cycle_9_post_review.md`
- **差し戻し指示**: `docs/handoff/P4_Rollback/cycle_9_post_review.md`
- **P4事後レビュー Take2**: `docs/handoff/P4_Dex_Review/cycle_9_post_review_take2.md`
- **差し戻し指示 Take2**: `docs/handoff/P4_Rollback/cycle_9_post_review_take2.md`
- **CC判断/マニュアルレビュー**: `docs/handoff/P4_Dex_Review/cycle_9_cc_judgement_and_air_manual_review.md`
- **CC作業中判断**: `docs/handoff/P4_Rollback/cycle_9_cc_judgement.md`

## 6. v2.3.0 Dexレビュー結果（前サイクル）

- 判定: **OK**
- P4 v2.3.0: `docs/handoff/P4_Dex_Review/cycle_8_3_v2_3_0.md`
- Dex側でも `書類.xlsx` をopenpyxlで読み、`R20 = ③ 旅行雑費` を確認済み。
- `project.getName()` による補助金区分判定は除去済み。
- 複数選択の単体様式出力も新シート名・グループ化へ統一済み。
- UIコンパクト化と検索順変更も確認済み。

## 7. Cycle 9 修正方針（UI最適化）

| Fix | 内容 | 状態 |
|-----|------|------|
| Fix1 | 名簿管理画面の横幅縮小（不要な余白削除） | 完了 / P4 OK |
| Fix2 | データ出力エリアの最大幅固定 | 完了 / P4 OK |
| Fix3 | 全体的なレスポンシブ見直し | 完了 / P4 OK |

## 8. 現在のStop Conditions / 禁止事項

以下はまだ禁止です。

- Airの手順整理前に実Claudeを自動起動する `-Watch -TestPhase2` 再テスト
- 本番P1での自動起動
- `git reset --hard` / `git restore .` / `git clean` の自動実行
- 自動ロールバック
- 第3段階への進行
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作

## 9. 次回実機テスト時の注意（Cycle 10 Maestro引き継ぎ）

- `test_automation:r2` はprocessed済みなので、次回はrevisionを上げる。
- ダミーP1はmanifest投入前に必ず作る。
- P1 → SHA-256計算 → manifest作成 → `.ready.json` 配置の順序を守る。
- OneDriveの大量削除確認が出たら、必ず「保持する」を選ぶ。
- 実Claude自動起動はKazumax承認後に1ケースずつ。
- `dummy_fail:r3` はprocessed済みのため、異常系再テストは `revision: 4` 以上で行う。
- 現時点では `docs/handoff/maestro/PAUSE` が存在する。再テスト前に意図して削除すること。

## 10. 各AIの作業完了時ルール（必須）

作業を終えるAIは、次担当へバトンを渡す前に必ず以下を行うこと。

1. この `CURRENT_STATUS.md` を現在地に合わせて更新する。
2. 最終チャットに「現在地サマリー」と「Kazumaxが次にコピペする合図文」を出す。
3. 合図文には、Cycle/Take、最新P1/P3/P4のパス、次担当者が読むべきファイルを含める。

## 11. このファイル自体の運用ルール

- **Single Source of Truth**: プロジェクトの現在地を示す単一の情報源として扱う。
- **履歴を積みすぎない**: 過去の詳細は各P1/P3/P4とTEAM_CHATに残し、このファイルは常に「今の瞬間」だけを示す。
- **必要時だけ読む**: AGENTS/AI_TEAM_WORKFLOW/TEAM_CHAT/proposalsは、CURRENT_STATUSや担当ルールで必要になった時だけ読む。

## 12. Kazumaxが次にコピーする合図文

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

CCへ：
Take2作業中の判断はA案です。
Kazumaxの明示承認を受けたうえで、replace.py / test.py / src/main/resources/templates/test.py を個別削除してください。
詳細は以下を読んでTake3修正してください。

- P3 Take2: docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take2.md
- Dex判断: docs/handoff/P4_Rollback/cycle_9_cc_judgement.md

Airへ：
マニュアル対策の客観レビューを保存しました。
方向性はOKですが、起動文への WORKFLOW_RULES.md 追加、Kazumax承認文言の明確化、Air直接編集禁止領域の明文化を検討してください。

- Dexレビュー: docs/handoff/P4_Dex_Review/cycle_9_cc_judgement_and_air_manual_review.md
- 提案: docs/proposals/Dex_workflow_rules_bootstrap_update.md
```
