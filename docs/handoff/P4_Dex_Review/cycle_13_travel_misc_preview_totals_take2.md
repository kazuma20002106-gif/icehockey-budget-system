[C13: Dex(P4) => Kazumax]

# Cycle 13 Take2 旅行雑費の画面表示合算漏れ・legacy preview日付修正 P4再レビュー

## 判定

**OK / Cycle 13完了**

CCのTake2修正は、Dexの差し戻し指摘を満たしています。

legacy 2-6 previewの「期日」「受領日」は、Excel側の `ExcelExportService.populate26(...)` と同じく、Expense側の日付を優先し、なければ事業日へフォールバックする表示になりました。

## サブレビュー利用判断

**不使用。**

理由:
- Take1 P4では金額・複数Expense・Excel整合をデクスクルー込みで確認済み。
- Take2差分は `preview.html` の2-6日付表示2箇所と `app.version` 更新に限定されている。
- 金額計算、DB、mapper、Excelテンプレート本体には新規差分がなく、Dex単独で最短・十分に確認できる範囲と判断した。

## Findings

**なし。**

差し戻し事項はありません。

## 確認内容

### 1. Take2差分範囲

確認コミット:

- `89a388d [v2.4.6] Cycle 13 Take2: legacy 2-6 previewの期日・受領日をExpense優先表示へ修正`

変更ファイル:

- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P3_CC_to_Dex/cycle_13_travel_misc_preview_totals_take2.md`
- `src/main/resources/application.properties`
- `src/main/resources/templates/export/preview.html`

DBスキーマ、mapper、Excelテンプレート本体、Java実装への追加差分はありません。

### 2. 2-6 previewの期日

OKです。

`src/main/resources/templates/export/preview.html` の2-6個人明細で、期日は以下の優先順位になっています。

1. `part.expense.expenseDate`
2. `pd.project.eventDate`

```html
<td th:text="${part.expense?.expenseDate != null ? #temporals.format(part.expense.expenseDate, 'M/d') : #temporals.format(pd.project.eventDate, 'M/d')}"></td>
```

これにより、Expense集約結果に期日がある場合はpreviewでもExcelと同じ日付を表示します。

### 3. 2-6 previewの受領日

OKです。

受領日も以下の優先順位になっています。

1. `part.expense.receiptDate`
2. `pd.project.eventDate`

```html
<td th:text="${part.expense?.receiptDate != null ? #temporals.format(part.expense.receiptDate, 'M/d') : #temporals.format(pd.project.eventDate, 'M/d')}"></td>
```

Excel側の `populate26(...)` は `Expense.receiptDate` 優先、なければ `project.eventDate` なので、previewとExcelの非数値日付表示は一致しました。

### 4. 雑費と旅行雑費の分離

OKです。

2-6の「雑費」列は引き続き `part.expense?.miscellaneousCost` のみを表示しています。
旅行雑費 `travelMiscCost` / `totalTravelMisc` / `pd.travelMiscTotal` は2-6の個人雑費列へ混ざっていません。

### 5. version同期

OKです。

```text
src/main/resources/application.properties: app.version=v2.4.6
target/classes/application.properties: app.version=v2.4.6
```

### 6. Dex検証

Dex側でも以下を確認しました。

```powershell
git diff --check HEAD^ HEAD
.\mvnw.cmd -q -DskipTests compile
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

結果:

- `git diff --check HEAD^ HEAD`: 問題なし
- sandbox内compile: Maven親POM解決のネットワーク制限で失敗
- 外側権限で同じcompileを再実行: 成功
- version同期: `v2.4.6` で一致

## 残リスク

複数Expenseの実データ検証は、Cycle 13 Take1から継続してmysqlクライアント等が環境になく未実施です。
ただし、今回のTake2対象である2-6 previewの日付優先順位は、静的差分とCCの一時テスト報告により、差し戻し指摘を満たすと判断します。

## Kazumax向け最終チェック

AIレビュー上はCycle 13 OKです。実機で見るなら、次だけ確認すれば十分です。

1. legacy「提出データ出力・集計」から様式2-6 previewを開く
2. 期日が入力されている経費は、その期日が表示される
3. 期日が空の経費は、事業日が表示される
4. 受領日も同じく、入力ありなら受領日、空なら事業日になる
5. 2-6の「雑費」列に旅行雑費が混ざっていない
6. `/activity?year=2026` の支出合計が、CC報告どおり `481,179円` から変わっていない

## 次の担当

**Kazumax**:

Cycle 13はP4 OKです。実機で軽く最終確認し、問題なければ次サイクルへ進めます。
