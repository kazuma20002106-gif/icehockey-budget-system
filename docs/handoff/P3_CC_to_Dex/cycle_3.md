[C3: CC(P3) ⇒ Dex(P4)]

Cycle 3 実装完了。レビューをお願いします。

## バージョン
v1.8.4 → v1.8.5

## コミット
f0e3fb9  [v1.8.5] C3: ツールチップ化・視認性・sticky隙間修正・交通費自動計算・交通手段4択・Excel連携

## git push origin main
実行済み。aba0172..f0e3fb9 → origin/main へ反映済み。

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `src/main/resources/templates/activity/form.html` | タスク1・3・4・5 |
| `src/main/resources/static/css/style.css` | タスク2・3 |
| `src/main/java/.../service/ExcelExportService.java` | タスク6 |
| `src/main/resources/application.properties` | v1.8.5 |

## 実装詳細

### タスク1：日付注意書きのツールチップ化
- `年度／活動日／受領日` ラベル横に Bootstrap Icons の `bi-info-circle` を配置
- `data-bs-toggle="tooltip" data-bs-trigger="hover focus" data-bs-html="true"` を付与
- `tabindex="0" role="button"` でスマホ tap/focus にも対応
- 従来の `<small>` 2行（div ブロックごと）を削除

### タスク2：ツールチップ視認性向上
- `--bs-tooltip-bg: #f8f9fa`（薄灰色）
- `--bs-tooltip-color: #212529`（濃い文字色）
- `.tooltip-inner` に `border: 1px solid #6c757d`（濃い枠線）
- 上下左右全方向の `.tooltip-arrow::before` に `border-{方向}-color: #6c757d` を追加

### タスク3：Sticky Header 隙間修正
- `<thead>` のインライン `style` を削除し CSS に移管
- `style.css` に `#rosterTable, #expenseTable` を `border-collapse: separate; border-spacing: 0;` で設定
- `#rosterTable thead th, #expenseTable thead th` に `position:sticky; top:0; z-index:2; background-color:#f8f9fa; background-clip:padding-box; box-shadow: 0 1px 0 #dee2e6;` を適用
- `box-shadow` により collapse 境界の隙間問題を解消

### タスク4：距離手入力時の自動計算
- `spinDigit()` を修正：`currentSpinnerTarget` が `.distance-input` の場合は `recalculateTransportCosts()` を呼び出し、それ以外は `calculateTotals()` を維持
- `expenseBody.addEventListener('input', ...)` で `.distance-input` への入力を委譲で検知し、その行の交通費を `距離 × 単価` で即時更新

### タスク5：交通手段の完全単体化
- th:each 既存行・非表示テンプレート行の両方を `航空機 / バス / 電車 / 自家用車` の4択に変更
- 旧値（`航空機・バス` / `電車・車`）は選択肢から削除

### タスク6：Excel 出力の交通手段連携
- `populate26()` の交通手段印字ロジックを新仕様に全面置換
- `buildTransportLabel(String method, Integer distKm)` private ヘルパーを追加
  - `航空機` → `航空機`
  - `バス` → `バス`
  - `電車` → `電車( 100 )㎞` （距離未入力は `電車(     )㎞`）
  - `自家用車` → `自家用車( 100 )㎞`
  - 旧値はデフォルトでそのまま出力（後方互換）
- 出力前にセル r・r+1（列13）をクリア、1行目に新交通手段、3行目に区間

## mvnw compile 確認
- BUILD SUCCESS（2026-06-12T16:20:48）
- Java 23ファイル再コンパイル成功
- `src`: v1.8.5 ✓
- `target/classes`: v1.8.5 ✓

## Dexへの確認依頼
1. タスク3：`border-collapse: separate` を2テーブルのみに限定（他テーブルへの影響なし）ことを実機で確認してください
2. タスク4：スピナーで距離を変更した場合も `recalculateTransportCosts()` が呼ばれ、全行の交通費が更新されることを確認してください
3. タスク5：編集画面表示時に旧値（`航空機・バス` / `電車・車`）が保存されているレコードは、セレクトが「未選択」状態になります。これは仕様（旧値を選択肢に残さない）として合意済みですが、挙動を確認してください
4. タスク6：Excel出力で `電車` / `自家用車` の距離付き表示が正しく印字されることを確認してください
