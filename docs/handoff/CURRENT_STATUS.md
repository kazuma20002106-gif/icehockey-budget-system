# CURRENT STATUS

> [!CAUTION]
> **Kazumax代表からの全体絶対ルール**
> 入力が簡単になっても、合算が正しくなければツールとして意味がない。合算が正常に行われているかを第一優先にする。

## Current Cycle

- Cycle 18: schema.sql の MySQL互換性（ALTER構文）修正

## 現在地

- Air(P1): Blueprint作成完了
- Dex(P2): 事前監査完了。CC(P3)向け最終指示書を作成済み
- CC(P3): 実装・実機検証（既存DB冪等確認・使い捨てDBでの列欠損検証）・compile確認完了。`docs/handoff/P3_CC_to_Dex/cycle_18_schema_alter_audit.md` に報告書を保存済み

## 次の担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_18_schema_alter_audit.md` を読んでDIFFレビューする

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `docs/handoff/P2_Dex_to_CC/cycle_18_schema_alter_audit_instructions.md`
6. `docs/handoff/P1_Air_Blueprint/cycle_18_schema_alter_audit.md`

## Cycle 18 重要ルール

- `ADD COLUMN IF NOT EXISTS` はMySQL 8で非対応のため削除し、`INFORMATION_SCHEMA`を使った安全な動的SQL（PREPARE構文）に書き換えること。
- 対象は `accommodation_nights`, `travel_misc_cost`, `travel_misc_days` の3列。
- 既存のKazumaxローカルDBのデータを破壊しないよう、列が存在しない場合のみ追加すること。
- Kazumaxの本物DBで `DROP TABLE` / `DROP COLUMN` を実行しないこと。
- `app.version` は v2.5.0 へ更新する。

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行の禁止
- `git add .` の自動実行の禁止
- 作業中の他AI/ユーザー差分を勝手に見落として戻さないこと
- 金額計算、Excel出力、DB、mapper、schemaに触る変更は、Air(P1) -> Dex(P2) -> CC(P3) -> Dex(P4) の完全プロセスを通す

## 履歴アーカイブ
- 古い進捗や過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` を参照
- 各サイクルの正式記録は `docs/handoff/P1_Air_Blueprint/`, `docs/handoff/P2_Dex_to_CC/`, `docs/handoff/P3_CC_to_Dex/`, `docs/handoff/P4_Dex_Review/`, `docs/handoff/P4_Rollback/` に保存済み
