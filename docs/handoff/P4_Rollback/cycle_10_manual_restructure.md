[C10: Dex(P4) => CC(P3) Take2]

# Cycle 10 マニュアル再整理 差し戻し指示 Take2

## 概要

現在のマニュアル構造は、共通テンプレ同期により入口ファイルが汎用化されすぎている。`manuals/` に共通ルールを置く方針は維持しつつ、アイスホッケー固有の強い安全ルールを入口ファイルへ戻すこと。

今回は Javaコード、DB、Excelテンプレート、`application.properties` は触らない。マニュアルのみの修正なので `app.version` 更新は不要。

## 修正対象

主に以下を修正する。

- `AGENTS.md`
- `CLAUDE.md`
- `.cursorrules`
- 必要なら `manuals/AI_TEAM_WORKFLOW.md`
- 必要なら `manuals/WORKFLOW_RULES.md`
- `docs/handoff/CURRENT_STATUS.md`

## 1. `AGENTS.md` にアイスホッケー固有の入口ルールを戻す

現在の共通テンプレ内容を全削除する必要はない。以下を追加して、最初に読むAIが必ず止まれるようにする。

必須で戻す内容:

- このプロジェクトでは、`docs/PROJECT_RULES.md` と `docs/handoff/WORKFLOW_RULES.md` も必読であること。
- Airは新しい依頼を受けたら、設計や実装案の前に「タスク重要度・事前宣言」を出すこと。
- 宣言には以下を含めること。
  - タスク要約
  - 危険度判定
  - 理由
  - 実行計画
- Kazumaxが明示的に「承認」「進めて」と返すまで、Airはコード編集しないこと。
- 危険タスクは `docs/PROJECT_RULES.md` を参照し、Air計画 -> Dex事前レビュー -> CC実装 -> Dex事後レビューを通すこと。
- コードまたはユーザー可視の挙動を変える場合、バージョン更新ルールは `docs/PROJECT_RULES.md` に従うこと。
- マニュアルのみの変更ではバージョンアップ不要。

## 2. `CLAUDE.md` に CC 固有の実装完了手順を戻す

現在の共通テンプレをベースにしてよいが、以下を必ず明記する。

- CCは `AGENTS.md`, `docs/handoff/CURRENT_STATUS.md`, `docs/PROJECT_RULES.md`, `docs/handoff/WORKFLOW_RULES.md` を読む。
- コード変更時は `src/main/resources/application.properties` の `app.version` を更新する。
- コード変更時は `.\mvnw.cmd -q -DskipTests compile` を実行する。
- `target/classes/application.properties` の `app.version` が同期していることを確認する。
- コミットメッセージ先頭に `[vX.Y.Z]` を付ける。
- 可能な状態ならコミットとpushまで行う。
- マニュアルのみの変更ではバージョンアップ不要。
- P3報告書は `docs/handoff/P3_CC_to_Dex/` に保存する。
- Kazumaxへのチャットは短くし、Dexへの合図文を単独コードブロックで出す。

## 3. `.cursorrules` に Dex 固有のP2/P4出力ルールを戻す

以下を必ず明記する。

- Dexは保存処理、DB、Excel出力、金額計算、参加者管理、日付計算を重点レビューする。
- P2を作る場合、CC向け指示書は `docs/handoff/P2_Dex_to_CC/` に保存する。
- P4レビューがNGの場合、修正指示は `docs/handoff/P4_Rollback/` に保存する。
- P4レビューがOKの場合、詳細レビューは `docs/handoff/P4_Dex_Review/` に保存する。
- Kazumax向け最終確認チェックリストは、P1要件を漏れなく含める。
- チャットは短い要約、判断、次担当合図に絞る。
- プラスアルファ提案がある場合は `docs/proposals/` にも保存する。

## 4. 共通テンプレとプロジェクト固有ルールの関係を明確にする

`manuals/` は共通ルールとして維持してよい。ただし、アイスホッケー固有の強いルールは次の場所に残す。

- 危険領域・検証条件: `docs/PROJECT_RULES.md`
- 引き継ぎ・出口ゲート: `docs/handoff/WORKFLOW_RULES.md`
- 現在地: `docs/handoff/CURRENT_STATUS.md`
- AI入口: `AGENTS.md`, `CLAUDE.md`, `.cursorrules`

## 5. `CURRENT_STATUS.md` を更新する

修正後、`CURRENT_STATUS.md` を以下の状態にする。

- Cycle 10: マニュアル再整理 Take2
- フェーズ: CC(P3) Take2完了 / Dex(P4) 再レビュー待ち
- 最新P3報告書のパスを記載
- 今回のP4 NGファイルとP4_Rollbackファイルのパスを記載

## 6. P3報告書を作成する

完了後、以下に報告書を作る。

```text
docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure_take2.md
```

報告書には以下を書く。

- 変更したファイル一覧
- `AGENTS.md` に戻したルール
- `CLAUDE.md` に戻したルール
- `.cursorrules` に戻したルール
- 共通テンプレ同期後の最終形として、どのファイルが入口で、どのファイルが固有ルールか
- Javaコード・DB・Excelテンプレート・`application.properties` を触っていないこと

## 7. CCへの合図

KazumaxがCCへ渡す場合は、以下を使う。

```text
デクスから差し戻しがあったよ。最新のファイルを読んで修正して！
```
