[C10: Dex(P4) => Kazumax]

# Cycle 10 マニュアル再整理 Take4 DIFFレビュー

## 判定

**OK**

Take4では、Take2/Take3で発生していた「入口ファイルに直接書いたプロジェクト固有ルールが、共通テンプレ同期で消える」問題の真因に対して、妥当な構成変更が行われています。

入口ファイル3点（`AGENTS.md`, `CLAUDE.md`, `.cursorrules`）へbudget-system固有ルールを直書きするのではなく、同期対象外の `docs/PROJECT_RULES.md` に本体を置き、入口ファイルから「存在する場合は必読・拘束力あり」として参照させる方針は、今後の同期運用と両立できます。

---

## 確認結果

### 1. 共通入口ファイルの設計

`AGENTS.md` は、`docs/PROJECT_RULES.md` と `docs/handoff/WORKFLOW_RULES.md` を「存在する場合は必読・拘束力あり」と明記しています。

また、プロジェクト固有ルールを `AGENTS.md` / `CLAUDE.md` / `.cursorrules` に直接書くと `マニュアル同期.ps1` で上書きされることも明記されており、Take2→Take3で起きた再発ポイントに対策できています。

### 2. CC向けルール

`CLAUDE.md` は、最初に読むものとして以下を含んでいます。

- `docs/PROJECT_RULES.md`（存在する場合・必読）
- `docs/handoff/WORKFLOW_RULES.md`（存在する場合・必読）

コード変更時のバージョン管理・ビルド・検証コマンドは `docs/PROJECT_RULES.md` に従う構成になっており、共通テンプレとして妥当です。

### 3. Dex向けルール

`.cursorrules` は、P2/P4の保存先、P4 OK/NG時の保存先、チャット短文化、次担当合図文の単独コードブロック化を保持しています。

重点レビュー領域は `docs/PROJECT_RULES.md` を優先確認する形になっており、プロジェクト固有情報を同期対象外へ寄せるTake4方針と整合しています。

### 4. budget-system固有ルール

`docs/PROJECT_RULES.md` の「0. Air / CC / Dex の追加ルール」に、Take3で要求した内容が移設されています。

- Air: 事前宣言、Kazumax承認待ち、危険タスクの完全プロセス
- CC: `app.version` 更新、compile、`target/classes/application.properties` 確認、`[vX.Y.Z]` コミット規約、P3報告、合図文コードブロック化
- Dex: P2/P4保存先、重点レビュー領域、P1要件を漏らさない最終チェックリスト

### 5. 共通テンプレートと同期スクリプト

デスクトップの `AI共通マニュアルテンプレ` 側にも、今回の汎用強化が反映されていることを確認しました。

`マニュアル同期.ps1` には、テンプレートと対象ファイルの内容が異なる場合に、上書き前バックアップを `docs/manual_legacy/` へ保存し、警告を出す処理が追加されています。無言で消える事故を避ける安全策として有効です。

---

## 残る注意点

Cycle 11相当の差分は、作業ツリー上にはまだ残っています。

- `mvnw.cmd`
- `docs/PROJECT_RULES.md` のclean compile追記
- `docs/handoff/WORKFLOW_RULES.md` の `git status --short` 出口ゲート追記

ただし、Take4報告でこの混在は明示され、Cycle 10 P4 OK後に別レビューへ回す方針も書かれています。Cycle 10の合否を止める問題ではありません。

---

## P4結論

Cycle 10 マニュアル再整理 Take4は **OK** です。

この構成なら、シフトなど別プロジェクトへ共通テンプレを同期しても、アイスホッケー固有ルールは `docs/PROJECT_RULES.md` に残り、入口ファイルから必ず読ませる流れになります。

次は、保留されていたCycle 11相当の運用・インフラ改善（`mvnw.cmd` など）を別サイクルとしてP4レビューするか、Kazumaxの判断で通常作業へ戻れます。
