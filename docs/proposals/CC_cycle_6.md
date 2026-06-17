# CC 提案 — Cycle 6 実装後の気づき

## 提案1: `layout.html` の activity/layout.html との SweetAlert2 共有

現在 `activity/list.html` は `activity/layout.html` を使っており、`layout.html` に追加した SweetAlert2 CDN が読み込まれない可能性がある（Thymeleafのフラグメント構造による）。

### 対処案
`activity/layout.html` にも同じ SweetAlert2 CDN を追加しておくと確実。または、layout.html を統合して1本化する（将来のメンテナンスコスト削減）。

## 提案2: `RootController` の `@RequestMapping("/")` 競合注意

今後 `DashboardController` を再作成しないよう、`AGENTS.md` や `CLAUDE.md` に「`/` ルートは `RootController` が担当」と明記するとチーム全体で認識共有できる。

## 提案3: アクティブユーザー未設定時の出力ガード

現在、activeUser が null でも Excel 出力は走る。記入責任者が空のまま出力されると帳票が不完全になる可能性がある。今後のサイクルで、未設定時に「ダウンロードボタンを非活性にする」か「警告確認モーダルを挟む」UIガードを追加することを提案。
