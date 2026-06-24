# 📍 CURRENT STATUS（現在地確認）

> **💡 Kazumax向け3行サマリー**
> - **今**: Cycle 8.3の実装をCCが完了（v2.2.0）。コンパイルOK。
> - **次**: DexがCCの実装差分をレビューする（P4）。
> - **Kazumaxの次アクション**: 下部の合図文をDexへ渡してください。

---

このファイルは、Air・CC・Dex・Kazumaxの全員が「今どこか」「次に何を読むか」「誰が何をするか」を迷わず確認するための1ページダッシュボードです。

## 1. 現在のサイクル名とフェーズ

**Cycle 8.3: UI改善・Excelシート名適正化・決算書旅行雑費修正**  
**CC実装完了 / Dexレビュー待ち**

## 2. 現在の担当者

**Dex** - CCの実装差分をレビュー（P4）

## 3. 次に作業する担当者

**CC** - Dexのレビュー結果次第（差し戻しあれば修正、OKなら完了）

## 4. 今読むべきファイル一覧

Dexが次に参照すべきファイル:

- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P1_Air_Blueprint/cycle_8_3_draft.md`
- `docs/handoff/P2_Dex_to_CC/cycle_8_3.md`
- `docs/handoff/P3_CC_Report/cycle_8_3.md`

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
- **P3 (CC Report)**: `docs/handoff/P3_CC_Report/cycle_8_3.md`（作成済み）

## 6. 現在のStop Conditions / 禁止事項

以下はまだ禁止です。

- Airの手順整理前に実Claudeを自動起動する `-Watch -TestPhase2` 再テスト
- 本番P1での自動起動
- `git reset --hard` / `git restore .` / `git clean` の自動実行
- 自動ロールバック
- 第3段階への進行
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作

## 7. CC実装完了サマリー（v2.2.0）

| 項目 | 内容 |
|------|------|
| コンパイル | `mvnw compile` Exit: 0 |
| バージョン | v2.1.14 → v2.2.0 |
| 絞り込み検索 | 種別・事業名を追加、一覧とExcel出力で同一条件を使用 |
| Excelシート名 | `2-4_選手強化費_成年男子_①` 形式、グループ化・ソート実装 |
| 2-4単独出力 | 常に左=対象・右=空欄（偶数番判定ロジック廃止） |
| 2-2-1旅行雑費 | `単価×人数×日数` で集計（R20セル推定・目視確認必要） |
| 宿泊費UI | 単価×泊数 input-group、rateは基本情報へ移動 |
| 宿泊費入力欄 | 2-6宿泊費セルを readonly 化 |
| 旅行雑費UI | `[単価]円×[日数]日×[人数]人=[合計]円` フル計算式 |
| 総合計表示 | tfoot を2行（旅費合計行 + 大きな総合計行）に分割 |

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
Dex、CCがCycle 8.3の実装を完了したよ。

最新のファイルは以下の通り。
- Air草案: docs/handoff/P1_Air_Blueprint/cycle_8_3_draft.md
- Dex補強版P2: docs/handoff/P2_Dex_to_CC/cycle_8_3.md
- CC実装報告(P3): docs/handoff/P3_CC_Report/cycle_8_3.md
- 現在地: docs/handoff/CURRENT_STATUS.md

@.cursorrules を厳守してDIFFレビュー（P4）をして！
作業が終わったら CURRENT_STATUS.md を更新して、ルールのテンプレートに従って次への合図文を出してね。
```
