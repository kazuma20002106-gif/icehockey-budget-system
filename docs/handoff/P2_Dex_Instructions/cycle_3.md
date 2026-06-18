# [C3: Dex(P2) => CC(P3)]

Cycle 3 の実装をお願いします。対象は活動日入力フォームの注意書きツールチップ化、ツールチップ視認性改善、Sticky Header の隙間修正、交通費自動計算、交通手段の単体化と Excel 出力連携です。

現在の最新バージョンは `v1.8.4` です。実装完了時は必ず `src/main/resources/application.properties` の `app.version` を `v1.8.5` に更新し、`.\mvnw compile` 後に `target/classes/application.properties` も `v1.8.5` になっていることを確認してください。

## ステータス

- Dex(P2) 作成完了
- CC(P3) 実装待ち

## 対象ファイル

- `src/main/resources/templates/activity/form.html`
- `src/main/resources/static/css/style.css`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/application.properties`

## 事前注意

- 既存のユーザー作業・他AI作業の差分を巻き戻さないこと。
- 既存の行追加、氏名ミラー、距離自動取得、合計計算、Excel 出力の既存仕様を壊さないこと。
- 実装後はローカルコミットだけで終わらず、必ず `git push origin main` を実行すること。
- Kazumax 向け完了報告には必ず「GitHubへプッシュしました」と明記すること。

## 実装要件

### 1. 日付注意書きのツールチップ化

`form.html` の基本情報内、「年度／活動日／受領日」ラベル直下にある以下の `small` 2行を削除してください。

- `年度（4月始まり）は活動日から自動判定されます`
- `※受領日はエクセル出力時に、活動日と同じ日付が自動印字されます`

代わりに、ラベル横へ Bootstrap Icons の情報アイコンを配置してください。

実装イメージ:

```html
<label class="form-label">
    年度／活動日／受領日 <span class="text-danger">*</span>
    <i class="bi bi-info-circle ms-1"
       tabindex="0"
       role="button"
       data-bs-toggle="tooltip"
       data-bs-trigger="hover focus"
       data-bs-html="true"
       title="年度（4月始まり）は活動日から自動判定されます。<br>受領日はエクセル出力時に、活動日と同じ日付が自動印字されます。"></i>
</label>
```

注意:
- スマホでタップしても表示できるように、`tabindex="0"` と `data-bs-trigger="hover focus"` を付けること。
- 既存のツールチップ初期化処理は活かしてよいが、必要なら `window.bootstrap` 判定内で全 tooltip 対象が初期化されるよう調整すること。

### 2. ツールチップの視認性向上

`style.css` の Tooltip セクションを強化してください。現在は白背景寄りですが、Air 指示どおり薄い灰色背景・濃い枠線・濃い文字色にして、ライトモードの画面背景と同化しない状態にしてください。

必須条件:
- `.tooltip` または `.tooltip-inner` で背景色を `#f8f9fa` などの薄い灰色にする。
- `.tooltip-inner` に `border: 1px solid #6c757d;` 相当の濃い枠線を付ける。
- 文字色は `#212529` など十分濃い色にする。
- `max-width: 350px` 前後、左揃え、読みやすい余白を維持する。
- `.tooltip-arrow` / `.tooltip-arrow::before` も背景・枠線と不自然に分離しないよう調整すること。

### 3. Sticky Header の隙間修正

様式2-5、様式2-6 のテーブルヘッダーは sticky 化済みですが、スクロール時にヘッダーと中身の間に隙間が見える問題を修正してください。

対象:
- `#rosterTable` の `thead th`
- `#expenseTable` の `thead th`

実装方針:
- インライン style だけで無理に対応せず、できれば `style.css` に専用 CSS を置くこと。
- `position: sticky; top: 0; z-index: 2; background-color: #f8f9fa;` を維持する。
- `box-shadow: 0 1px 0 #dee2e6;` や `background-clip: padding-box;` などを使い、スクロール時の隙間を完全に塞ぐこと。
- 必要に応じて対象テーブルに `border-collapse: separate; border-spacing: 0;` を適用してよい。ただし他のテーブル表示を壊さないよう、セレクタは `#rosterTable`, `#expenseTable` に限定すること。

### 4. 2-6 交通費の手入力時自動計算

`form.html` には `recalculateTransportCosts()` が既にありますが、距離欄や単価欄を手入力した瞬間に確実に再計算されるようにしてください。

必須条件:
- `#transportRate` の `input` 時に `recalculateTransportCosts()` が発火すること。
- `.distance-input` の `input` 時に、その行の交通費が `距離 × 単価` で即時更新されること。
- 行追加後の `.distance-input` にも効くよう、`expenseBody.addEventListener('input', ...)` のイベント委譲で実装すること。
- 距離スピナーの `spinDigit()` で距離を変更した場合も交通費が再計算されること。`currentSpinnerTarget` が `.distance-input` の場合は `recalculateTransportCosts()`、金額欄の場合は従来どおり `calculateTotals()` になるよう分岐してください。
- 交通費を手入力で上書きした場合の既存挙動は可能な限り維持。ただし距離または単価を変更した時点では自動計算値で上書きされてよいです。

### 5. 交通手段の完全単体化

`form.html` の交通手段セレクトボックスを、既存行・テンプレート行の両方で以下の4択に変更してください。

廃止:
- `航空機・バス`
- `電車・車`

新しい選択肢:
- `航空機`
- `バス`
- `電車`
- `自家用車`

既存DBに旧値が入っている場合への最低限の後方互換として、編集画面表示時に旧値が選ばれていても画面が破綻しないよう注意してください。実装が複雑になりすぎる場合は、旧値を選択肢に残さず、新規保存以降は4択だけになる仕様で構いません。

### 6. Excel 出力の交通手段連携

`ExcelExportService.java` の `populate26()` を修正し、様式2-6 の交通手段欄に、選択された単体交通手段が正しく印字されるようにしてください。

現在の実装は以下の前提になっています。
- 1行目: `航空機・ﾊﾞｽ`
- 2行目: `電車・車(  )㎞`
- `電車・車` のときだけ距離を入れる

これを新仕様に合わせて変更してください。

期待仕様:
- `航空機` 選択時: 交通手段欄に `航空機` を印字。
- `バス` 選択時: 交通手段欄に `バス` を印字。
- `電車` 選択時: 交通手段欄に `電車( 100 )㎞` のように距離付きで印字。
- `自家用車` 選択時: 交通手段欄に `自家用車( 100 )㎞` のように距離付きで印字。
- 距離が未入力の場合は、`電車(    )㎞` / `自家用車(    )㎞` のように空欄相当でよい。
- 交通区間は従来どおり3行目に出力すること。

推奨実装:
- `populate26()` 内で交通手段表示文字列を作る private helper を追加してよい。
- 出力前に該当3行の交通手段セルを一度クリアし、1行目に新仕様の交通手段、3行目に区間を出す形が分かりやすい。
- 旧テンプレート文字列 `航空機・ﾊﾞｽ` や `電車・車` を残さないこと。

## 検証項目

実装後、最低限以下を確認してください。

- `.\mvnw compile` が `BUILD SUCCESS` になる。
- `src/main/resources/application.properties` と `target/classes/application.properties` の `app.version` がどちらも `v1.8.5`。
- 活動日入力画面で日付欄下の `small` 2行が消えている。
- 日付ラベル横の情報アイコンで、PC hover/focus とスマホ想定 tap/focus の両方でツールチップ表示できる。
- ツールチップが薄灰色背景・濃い枠線・濃い文字色で読みやすい。
- 様式2-5、2-6 の sticky header でスクロール時に隙間が出ない。
- 2-6 で距離を手入力した瞬間に交通費が `距離 × 単価` で更新される。
- 交通費単価を変更した瞬間に全行の交通費が再計算される。
- 行追加後の距離欄でも同じ自動計算が効く。
- 交通手段セレクトが `航空機` / `バス` / `電車` / `自家用車` の4択になっている。
- Excel 出力の様式2-6で、選択した交通手段と距離が期待どおり印字される。

## 完了時の必須作業

1. `app.version=v1.8.5` に更新する。
2. `.\mvnw compile` を実行する。
3. `target/classes/application.properties` の `app.version=v1.8.5` を確認する。
4. 変更をコミットする。
5. 必ず `git push origin main` を実行する。
6. P3 報告書を `docs/handoff/P3_CC_to_Dex/cycle_3.md` に作成する。
7. Kazumax 向けチャット報告の最後に「GitHubへプッシュしました」と明記する。

## P3 報告書に必ず書くこと

- 変更ファイル一覧
- 実装内容の要約
- `.\mvnw compile` の結果
- `src` と `target/classes` のバージョン確認結果
- コミットハッシュ
- `git push origin main` の実行結果
- Dex(P4) に確認してほしい観点

## 提案

提案なし。

## ⏩ 次の担当への合図（コピペ用）

```text
CCへ。docs/handoff/P2_Dex_to_CC/cycle_3.md を読んで、Cycle 3 の実装をお願いします。完了後は .\mvnw compile、app.version=v1.8.5 の src/target 同期確認、コミット、git push origin main まで実施し、docs/handoff/P3_CC_to_Dex/cycle_3.md に報告書を作成してください。Kazumax向け報告には「GitHubへプッシュしました」と明記してください。
```
