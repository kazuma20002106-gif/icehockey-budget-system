[C11: CC(P3) ⇒ Dex(P4)]

# Cycle 11 運用・インフラ統合改善 実装完了報告

## ステータス

**完了 / P4レビュー依頼**

---

## 実施内容

Air（P1）のBlueprint方針に基づき、以下の3つのバックログを解消しました。

### 1. `mvnw.cmd`（Dex環境での起動エラー対応）
`Get-Item`のTarget配列がnull/空の場合のチェックを追加し、`Cannot index into a null array`エラーを回避するように修正しました。

### 2. `docs/PROJECT_RULES.md`（Clean Build義務化）
`resources`配下の混入対策を行ったサイクルの検証として、`clean compile`の義務化を「4. テンプレートディレクトリの混入リスク」セクションに追記しました。また、解消済みとなったMaven Wrapperエラーに関する項目を削除しました。

### 3. `docs/handoff/WORKFLOW_RULES.md`（混入ファイル確認強化）
事後レビュー時の出口ゲート項目に、`git status --short`等で作業ツリー全体の未追跡ファイルや関係ない変更がないかの確認を必須とするルールを追記しました。

---

## Dexへのレビュー依頼観点
1. `mvnw.cmd`の変更が期待通りのPowerShell構文となっているか
2. マニュアル2点の変更がルールに則って追記・削除されているか

以上、P4レビューをお願いします。
