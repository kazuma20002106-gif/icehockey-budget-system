[C10: Dex(P4) => CC(P3) Take2]

# Cycle 10 マニュアル再整理 P4レビュー

## レビュー結果

NG。

4層構造へ分ける方針自体は良いが、現在の作業ツリーでは共通マニュアル同期の影響で、アイスホッケー固有の強い入口ルールが薄くなっている。この状態では、Air・CC・Dexが新チャットで動いたときに、以前防げていた事故を再発させる可能性がある。

## ブロッカー

### 1. `AGENTS.md` から Air の事前宣言・承認待ちルールが消えている

現在の `AGENTS.md` は共通テンプレ寄りになっており、以前あった以下のルールが入口から消えている。

- Airが新しい依頼を受けたら、危険度判定と実行計画を先に出す。
- Kazumaxが明示的に承認するまでコード編集しない。
- Air直接編集禁止領域は `docs/PROJECT_RULES.md` を参照する。
- 危険タスクは Air計画 -> Dex事前レビュー -> CC実装 -> Dex事後レビュー。
- コード変更時のバージョン更新は `docs/PROJECT_RULES.md` に従う。

`docs/PROJECT_RULES.md` に危険領域はあるが、Airが最初に止まって宣言するルールは入口である `AGENTS.md` に必要。

### 2. `CLAUDE.md` から CC 固有の完了手順が消えている

現在の `CLAUDE.md` は共通テンプレ化され、以下が弱くなっている。

- タスク完了ごとのコミット。
- コード変更時の `app.version` 更新。
- `.\mvnw.cmd -q -DskipTests compile` と `target/classes/application.properties` 同期確認。
- コミットメッセージ先頭の `[vX.Y.Z]`。
- push。
- P3報告書を `docs/handoff/P3_CC_to_Dex/` に保存する詳細ルール。
- Kazumax向けチャットを短文にし、Dexへの合図文を出すルール。

`docs/PROJECT_RULES.md` に一部はあるが、CCが最初に読む `CLAUDE.md` に要約版が必要。

### 3. `.cursorrules` から Dex 固有のレビュー観点と出力形式が落ちている

現在の `.cursorrules` はかなり短く、以下が弱くなっている。

- P2作成時は `docs/handoff/P2_Dex_to_CC/` に保存し、チャットは短い合図にする。
- P4レビュー時は OK/NG、確認内容、判断、提案、現在ステータス、次担当合図を出す。
- P4 OK時のKazumax向け最終確認チェックリストは、P1要件を網羅する。
- NG時は `docs/handoff/P4_Rollback/` に修正指示を保存する。
- 保存処理、DB、Excel出力、金額計算、参加者管理を重点レビューする。

Dexの入口が弱いと、レビュー結果がチャットだけで散らばりやすくなる。

### 4. P3報告の「4ファイル編集」と現状の差分が一致していない

P3報告では主に以下4ファイルと説明されている。

- `docs/PROJECT_RULES.md`
- `AGENTS.md`
- `docs/handoff/WORKFLOW_RULES.md`
- `docs/handoff/CURRENT_STATUS.md`

しかし現状は、共通同期により `.cursorrules`, `CLAUDE.md`, `manuals/`, `AI_TEAM_WORKFLOW.md` なども関係している。これは悪い変更とは限らないが、Cycle10レビュー対象として明示されていないため、Take2では「共通テンプレ同期後の最終形」として報告を更新する必要がある。

## 修正指示

CCは `docs/handoff/P4_Rollback/cycle_10_manual_restructure.md` を読んで、Take2修正を行うこと。

## 良かった点

- `docs/PROJECT_RULES.md` の危険領域分離は良い。
- 金額・Excel・DB・テンプレート混入リスクは明確になっている。
- `docs/handoff/WORKFLOW_RULES.md` のリカバリプロトコルと `CURRENT_STATUS.md` 更新責任は有用。
- `manuals/AI_TEAM_WORKFLOW.md` の「通常タスクはAir直行、危険タスクはDex事前監査」は最新版運用として適切。

## 現在ステータス

Cycle 10 マニュアル再整理は P4レビューNG。CC Take2修正待ち。
