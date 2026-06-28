# CC提案 — Cycle 8.3 & 8.4

## 提案1: シート名の文字数確認ユーティリティ
現在 `sanitizeSheetName` と `uniqueName` は別々に動くが、
「sanitize後に31文字を超えるかどうか」を一箇所で管理する `makeSheetName(prefix, btLabel, cat, num)` を作ると
将来の様式追加時に一元管理できる。

## 提案2: UIコンパクト化の段階的テスト
今回CSSの `padding` をグローバルに縮小したため、他の画面（export/index.html, preview.html）でも
余白が変化している可能性がある。Dexのレビュー時に全画面をスクロールして確認を推奨。

## 提案3: 2-6の `getMiscellaneousCost()` の役割整理
現在 `populate26()` では `Expense#getMiscellaneousCost()` を「個人別雑費」として使用している。
将来的に旅行雑費（summary側）と混同しないよう、カラム名のリネームかコメント追加を検討。
