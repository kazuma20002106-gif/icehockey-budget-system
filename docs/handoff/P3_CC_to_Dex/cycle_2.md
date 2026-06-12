[C2: CC(P3) ⇒ Dex(P4)]

実装完了。レビューをお願いします。

## バージョン
v1.8.2 → v1.8.3

## コミット
c3c14c8  [v1.8.3] form.html UX改善：初期値・標準サイズ化・stickyヘッダー・高さ調整・ツールチップ・注釈修正

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `src/main/resources/templates/activity/form.html` | タスク1〜4・6 すべて対応 |
| `src/main/resources/static/css/style.css` | タスク5：ツールチップCSSを追加 |
| `src/main/resources/application.properties` | app.version=v1.8.3 に更新 |

## 実装詳細

### タスク1：事業の成果の初期値設定
- `projectOutcome` textarea の placeholder を削除
- `th:text` に Thymeleaf 条件式を追加。値が null または空文字の場合は `技術力・チーム連携の向上` を初期表示

### タスク2：テーブル入力欄の縮小サイズ除去
- `form-select-sm`、`form-control-sm`、`input-group-sm` を全削除（両テーブル本体＆非表示テンプレート行を含む全箇所）

### タスク3：テーブルヘッダーの固定（Sticky化）
- 参加者名簿・個人別支出の両 `thead` に `position:sticky; top:0; z-index:2; background-color:#f8f9fa;` を追加

### タスク4：縦スクロール領域の高さ最適化
- 両テーブルの `max-height: 220px` → `max-height: 320px` に変更
- 標準サイズ行高（約64px）× 4行 ＋ ヘッダー（約45px）= 約300px を考慮し320pxに設定

### タスク5：ツールチップの視認性改善
- `style.css` に Bootstrap 5 カスタムプロパティでツールチップを上書き
- 白背景・黒文字・左揃え・0.95rem・最大幅350px・ボーダー付きシャドウ

### タスク6：注釈テキストの改行修正
- 日付欄下の `<small>` 2要素を `d-block` + `mt-1` でブロック表示に変更し、不自然な改行を解消

## mvnw compile 確認
- BUILD SUCCESS（2026-06-12T14:38:13）
- `src/main/resources/application.properties`: v1.8.3 ✓
- `target/classes/application.properties`: v1.8.3 ✓

## Dexへの確認依頼
- タスク2の `-sm` 除去は 両テーブルのヘッダー行を除く本体・テンプレート行のすべての input/select/input-group に適用しています。ヘッダーの `th` 要素は変更対象外です
- タスク4の max-height 320px が「ヘッダー1行＋4行」の視認要件を満たしているか、実機で確認をお願いします
