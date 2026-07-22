# [C8.3: Dex(P4) ⇒ Kazumax] Cycle 8.3 & 8.4 DIFFレビュー

## レビュー結果

**OK**

最新コミット:

- `73165b4 [v2.3.0] Cycle 8.3&8.4: Excelシート名修正・budgetTypeLabel統一・検索順変更・UIコンパクト化`
- `7bafeb8 [v2.3.0] P3報告書・提案書を追加 (cycle_8_3)`

CCの最新P3は `docs/handoff/P3_CC_to_Dex/cycle_8_3.md`。
旧 `docs/handoff/P3_CC_Report/cycle_8_3.md` はv2.2.1の古い報告なので、今回のレビュー対象ではない。

## 確認内容

### 1. ExcelExportService

OK。

- `budgetTypeLabel(null)` が `未設定`、defaultが `その他` になっている。
- `project.getBudgetType()` は使っていない。
- `project.getName()` の残存は `pruneTemplateEllipses24Side` の図形削除用途で、補助金区分判定ではないため許容。
- 2-2-1旅行雑費は `travelMiscCost * participants.size() * travelMiscDays` をJ20へ出力している。
- 2-4/2-5/2-6のソートとグループ内連番は既存の正しい実装を維持している。

注意:

- `uniqueName()` は31文字へ切り詰めたあと、同名衝突時に `_1` を足すため、理論上は31文字を超える可能性がある。
- 現行の補助金区分・種別の固定値では生成名が21文字程度で、今回の通常運用では問題化しにくい。
- 将来、長い種別名をDBへ入れる可能性があるなら、suffix分を差し引いて再切り詰めする helper に直すとより安全。

### 2. 活動一覧 list.html

OK。

- 検索順は `年度 → 月 → 補助金区分 → 種別 → 事業名`。
- `projectName` は `form-control form-control-sm` になり、以前の `form-select` 誤用は修正済み。
- 年度まとめExcelリンクに `targetCategory` と `projectName` が引き継がれている。

### 3. UIコンパクト化

OK。

- `style.css` のテーブル、フォーム、ボタン、main-contentの余白が縮小されている。
- `activity/form.html`、`activity/list.html`、`members/index.html` の対象範囲内で小型化されている。
- `layout.html` は現行でサイドバーを描画していないため、`.main-content` の `margin-left` なしは直近のレイアウト修正意図と整合している。

### 4. バージョン

OK。

- `src/main/resources/application.properties` は `app.version=v2.3.0`。

### 5. P3 / 提案

概ねOK。

- 最新P3は `docs/handoff/P3_CC_to_Dex/cycle_8_3.md` に保存されている。
- プラスアルファ提案は `docs/proposals/CC_cycle_8_3.md` に保存されている。
- ただしP2内では `docs/handoff/P3_CC_Report/cycle_8_3.md` と書かれており、P3保存先が新旧で揺れている。次サイクルでフォルダ名を統一した方がよい。

## Dex環境での検証

- `git diff --stat 8ec91c8..HEAD` で変更範囲を確認。
- `git show` で `73165b4` と `7bafeb8` の差分を確認。
- 静的レビューでP2主要条件を照合。
- `git diff --check 8ec91c8..HEAD` はP3ファイル先頭2行のtrailing whitespaceのみ検出。コード差分には検出なし。
- `.\mvnw.cmd -q -DskipTests compile` はDex環境のMaven Wrapper起動問題で実行不可。
  - エラー: `Cannot index into a null array. Cannot start maven from wrapper`
  - CCのP3ではコンパイル成功報告あり。

## Kazumax向け最終確認チェックリスト

1. 画面右下またはナビのバージョンが `v2.3.0` になっている。
2. 活動一覧の検索欄が `年度 → 月 → 補助金区分 → 種別 → 事業名` の順に並ぶ。
3. 活動一覧で検索条件を入れた状態の「年度まとめExcel出力」が、一覧と同じ対象だけを出す。
4. 複数事業Excelでシート名が `2-4_補助金区分_種別_①` 形式になっている。
5. 2-4は同じ補助金区分 + 同じ種別だけで左右ペアになる。
6. 2-2-1の旅行雑費が `単価 × 人数 × 日数` でJ20へ出る。
7. 活動入力、活動一覧、名簿管理の余白が詰まり、表示崩れやボタン文字の欠けがない。

## 判定

Cycle 8.3 & 8.4 v2.3.0 は **P4レビューOK**。

