# CC ＋α提案 — サイクル2

## 提案1：max-height の数値をCSS変数化する（自己進化）

今回の差し戻しは `max-height` の数値がハードコードされていたことが根本原因です。
`style.css` に CSS カスタムプロパティ（変数）として定義しておけば、数値の調整が1ファイル1行の変更で完結し、差し戻しリスクが大幅に低減します。

```css
/* style.css */
:root {
    --table-scroll-height: 350px;
}
```

```html
<!-- form.html -->
<div class="table-responsive" style="max-height: var(--table-scroll-height); overflow-y: auto;">
```

## 提案2：P4_Rollback フォルダの Git 運用ルール化

Dexが差し戻しファイルを `docs/handoff/P4_Rollback/cycle_〇.md` に書く運用が今サイクルで初めて実施されました。
Dex側（.cursorrules）にも「差し戻し時は必ずこのパスにファイルを書く」というルールを明文化することを推奨します。
