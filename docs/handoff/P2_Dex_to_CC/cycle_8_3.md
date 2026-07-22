# Cycle 8.3 & 8.4 統合実装指示書 (P1/P2)

## 📌 背景と目的
Cycle 8.3でロールバックされた「Excel出力・金額計算バグ」の修正と、Cycle 8.4の「UIコンパクト化（余白削減）」を同時に実施します。
本ドキュメントはAirの仕様設計（P1）に対し、Dexの事前監査（Pre-Audit）を通した**「絶対に事故らないためのCC向け最終実装指示書（P2）」**です。

## ⚠️ CCへの厳格なルール
- これは**危険タスク**です。DBの変更や不要な大規模リファクタリングは厳禁です。
- 以下の指示に忠実に従い、完了後は `docs/handoff/P3_CC_Report/cycle_8_3.md` に結果を報告してください。

---

## 📝 実装指示詳細

### 1. 補助金区分の安全な取得（ExcelExportService.java）
- `Project` モデルには `budgetTypeId` のみが存在し `BudgetType` エンティティの紐付けはありません。
- **絶対に `project.getBudgetType()` や `project.getName()` を使って推測しないこと。**
- `ActivityController#budgetLabel` のロジックを参考に、`ExcelExportService` 内に以下のようなヘルパーメソッドを作成し、これを用いて補助金区分文字列（"選手強化費" 等）を取得してください。
  ```java
  private String budgetTypeLabel(Integer budgetTypeId) {
      if (budgetTypeId == null) return "未設定";
      return switch (budgetTypeId) {
          case 1 -> "選手強化費";
          case 2 -> "トップチーム活用事業";
          case 3 -> "ふるさと選手活動支援";
          default -> "その他";
      };
  }
  ```

### 2. Excelシート名の生成と安全条件
- 一括出力・単独出力ともに、シート名を `[様式]_[補助金区分]_[種別]_[連番]` に変更します。（例：`2-4_選手強化費_成年男子_①`）
- **【必須制約】**
  - 文字数は31文字以内に切り詰めること。
  - Excelで使えない文字（`\ / ? * [ ] :`）は空白またはアンダースコア等に置換すること。
  - 同名シートが生成された場合は、既存の重複回避ロジック（`uniqueName`）を通すこと。

### 3. 一括出力時のソート順（固定）
一括出力時のシートの出力順は、以下のルールで**完全に固定**してください。
1. `budgetTypeId` の昇順
2. `targetCategory`（種別）の順：`成年男子` → `成年女子` → `少年男子` → `少年女子` → その他
3. `eventDate`（活動日）の昇順
4. `id` の昇順

### 4. 2-4出力のペアリングと単独出力
- 2-4結合のグループキーは `budgetTypeId + targetCategory` とします。
- グループ内で活動日昇順に並べ、古い日付を左側、新しい日付を右側にペアリングします。
- 1件余った場合、または単独出力の場合は、**必ず左側に対象を出力し、右側は `clearSide24` 等を用いて空欄化**してください。
- 採番はグループごとに①から振り直してください。単独出力時も①等正しい連番になります。

### 5. 2-2-1旅行雑費セルの確定と出力
- 2-2-1の旅行雑費の集計ロジックを以下に変更します：
  `summary.getTravelMiscCost() * (人数) * summary.getTravelMiscDays()` の合計値
- **【超重要】** 出力先のセルについて、実装前に必ず `書類.xlsx` の様式2-2-1を `openpyxl`（Pythonスクリプト等）で読み解くか、実ファイルの中身を検索して「旅行雑費」行（R20など）のセル座標を確実に特定してください。
- 特定できた場合のみJavaコードを修正し、特定した座標と根拠をP3に記載すること。特定できない場合は別行に推測出力せず、エラーとしてP3で報告して止まること。
- 旧カラム `Expense#getMiscellaneousCost()` は2-2-1の決算集計に使わないこと。

### 6. UI / UX改善（form.html / list.html / ActivityController）
- **活動一覧（list.html）の検索追加**
  - 絞り込み入力欄に「種別」のプルダウンと「事業名」の部分一致検索を追加する。
  - 配置順を「年度 → 月 → 補助金区分 → 種別 → 事業名」とする。
- **活動フォーム（form.html）の複合入力・自動計算**
  - 宿泊：`[単価]円 × [日数/泊数]泊`
  - 旅行雑費：`[単価]円 × [日数]日 × [人数]人 = [合計]円` （JSの `updateTravelMiscTotal` で自動計算）
- **宿泊費0円の上書き防止**
  - 単価0円入力時に、名簿側の既存宿泊費を0で上書きしない（既存値を維持する）ロジックを確実に残す。様式2-6明細行の宿泊費入力欄は `readonly` 化する。

### 7. UIコンパクト化の範囲指定（Cycle 8.4）
- 大規模なHTMLリファクタリングは禁止します。対象は以下のファイルのみです。
  - `src/main/resources/static/css/style.css`
  - `src/main/resources/templates/activity/form.html`
  - `src/main/resources/templates/activity/list.html`
  - `src/main/resources/templates/members/index.html`
- **修正内容**
  - CSSの `.table tbody td` のパディング縮小（例: `6px 8px`）。
  - `form-control` 等を `form-control-sm` / `btn-sm` 等へ部分的に置き換え、カードのパディング（`p-2`等）を削り、無駄な余白を減らす。
  - 変更後、UIが極端に崩れないかブラウザ表示レベルで配慮すること。
