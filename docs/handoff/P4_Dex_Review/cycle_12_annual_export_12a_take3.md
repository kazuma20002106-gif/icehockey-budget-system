[C12: Dex(P4) => Kazumax / CC(P3)]

# Cycle 12A Take3 年度末決算ファイル一括出力 P4再レビュー

## 判定

**OK / 12A完了**

Take2で差し戻した「選手強化費2-2-1の女性側内訳欄がAL列へ書かれる問題」は、Take3で修正済みです。12AはP4 OKとし、12B（予算管理・様式2-3連動）へ進んでよいです。

## 確認結果

### 1. 女性側内訳列

`src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java` の `writeBreakdownPair` を確認しました。

```java
writeSafeNumeric(sheet, topRow0idx, 31, adultFemale);
writeSafeNumeric(sheet, topRow0idx + 1, 31, youthFemale);
```

0始まり列番号 `31` は `AF` 列です。原本テンプレートでは `AF:AK` が女性側金額欄、`AL` が単位「円」欄なので、前回の破壊リスクは解消されています。

### 2. 原本テンプレート構造

`src/main/resources/書類.xlsx` の `様式２－２－１　事業別決算書（選手強化費）` をXMLで再確認しました。

- 男性側金額欄: `S:X`
- 女性側ラベル欄: `AB:AE`
- 女性側金額欄: `AF:AK`
- 女性側単位欄: `AL`
- 外部リンク: 0件

Take3の実装はこの構造と一致しています。

### 3. ビルド

Dex側でも以下を実行し、成功しました。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

`src/main/resources/application.properties` と `target/classes/application.properties` の `app.version` はどちらも `v2.4.0` で一致しています。

## 非ブロッカー

`writeTraining221Breakdown` のメソッド上部コメントに、女性側を「AL列に値」とする古い説明が1行残っています。ただし実行コードと `writeBreakdownPair` 直近コメントは `AF` で正しく、出力破壊にはつながらないため、12A完了を止めるブロッカーにはしません。

12B以降で `ExcelExportService.java` を触る場合は、このコメントも `AF列` に直してください。

## Kazumax向け短縮チェック

- [x] 女性側内訳は `AF` 列へ書き込む
- [x] `AL` 列の「円」を上書きしない
- [x] 外部リンク0件
- [x] compile成功
- [x] app.version同期確認済み

## 次の担当

**CC(P3)**:

12AはP4 OKです。次は12Bへ進んでください。

最優先で次を読んでください。

`docs/handoff/P2_Dex_to_CC/cycle_12b_budget_allocations_form23_instructions.md`

12B完了後は、次へ報告してください。

`docs/handoff/P3_CC_to_Dex/cycle_12b_budget_allocations_form23.md`
