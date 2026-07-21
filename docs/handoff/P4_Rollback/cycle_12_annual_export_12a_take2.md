[C12: Dex(P4) => CC(P3) Take3]

# Cycle 12A Take2 年度末決算ファイル一括出力 P4再レビュー

## 判定

**NG / CC Take3差し戻し**

Take2で、前回Findingのうち次の2点は解消方向で確認しました。

- 対象事業0件時は年度末出力を止め、選択年度を保持して一覧へ戻す実装になっている
- 様式2-1のAA42/AA43は `UserSettingService.getActiveUser()` から担当者/TELを書き込む実装になっている

ただし、2-2-1選手強化費の女性側内訳欄の書き込みセルが原本構造とずれており、金額セルではなく単位「円」のセルを上書きします。年度末決算ファイルの金額欄なので、12Bへ進む前に必ずTake3で修正してください。

## Finding

### P1: 選手強化費2-2-1の女性側内訳をAL列へ書いている

対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `writeTraining221Breakdown`
- `writeBreakdownPair`

Take2実装:

```java
writeSafeNumeric(sheet, topRow0idx, 37, adultFemale);      // AL列（成年女子）
writeSafeNumeric(sheet, topRow0idx + 1, 37, youthFemale);  // AL列 次行（少年女子）
```

しかし原本 `src/main/resources/書類.xlsx` の `様式２－２－１　事業別決算書（選手強化費）` をXMLで確認すると、女性側は次の構造です。

- `AB:AE`: 成年女子/少年女子ラベル
- `AF:AK`: 金額欄
- `AL`: 単位「円」

つまり、0始まり列番号では以下が正しいです。

- 男性側金額欄: `S` = 18（Take2のままでOK）
- 女性側金額欄: `AF` = 31
- `AL` = 37 は単位「円」なので書き込み禁止

このままだと成年女子/少年女子の内訳金額が本来の金額欄に入らず、単位セルを壊します。

## Take3修正指示

1. `writeBreakdownPair` の女性側書き込み列を `37(AL)` から `31(AF)` へ変更してください。
2. コメントも「AL列」ではなく「AF列」に直してください。
3. `AL16/AL17/.../AL33` は単位「円」のまま残ることを確認してください。
4. 選手強化費2-2-1の内訳欄について、最低限以下を検証してください。
   - 成年男子の金額が `S16/S18/...` に入る
   - 少年男子の金額が `S17/S19/...` に入る
   - 成年女子の金額が `AF16/AF18/...` に入る
   - 少年女子の金額が `AF17/AF19/...` に入る
   - `AL16:AL33` は「円」のまま

## 追加確認

`mvnw.cmd -q -DskipTests compile` はDex側でも成功しました。

ただし、ワーキングツリー上では `src/main/resources/書類.xlsx` がGit基準から変更済みです。これはTake1の外部リンク除去由来であれば許容範囲ですが、Take3ではテンプレートを不要に触らず、もし触った場合は必ずP3報告書に明記してください。

## 次の担当

**CC(P3 Take3)**:

このP4_Rollbackを読んで、Cycle 12A Take3修正を行ってください。

Take3完了後は、次へ報告してください。

`docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a_take3.md`

12A Take3がDex(P4) OKになるまで、12Bには進まないでください。
