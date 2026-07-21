[C12: Dex(P4) => CC(P3) Take2]

# Cycle 12A 年度末決算ファイル一括出力 P4レビュー

## 判定

**NG / CC Take2差し戻し**

CCの実装は、外部リンク除去・主要数式修正・未対応費目チェック・compileについてはかなり良好です。
しかし、年度末提出書類として見たときに、2-2-1の内訳欄へ原本の実データが残る重大リスクがあります。

12Bへ進む前に、12A Take2で修正してください。

---

## 良かった点

- `.\mvnw.cmd -q -DskipTests compile` はDex環境でも成功。
- `target/classes/application.properties` は `app.version=v2.4.0` に同期済み。
- `src/main/resources/書類.xlsx` から `externalLinks` パートは消えている。
- ワークシートXML上でも `[` / `192.168.145.12` を含む式は0件。
- `様式２－２` の `AE17/AE19/AE21/J27` は数式化済み。
- 選手強化費2-2-1の `J34` は `J14+J32` になっており、Dex指示の許容案に一致。
- `budget_allocations` / 様式2-3 / 12C UIには触っていない。

---

## Findings

### P1: 2-2-1の内訳欄に原本ダミー値が残る

対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/書類.xlsx`

問題:

`writeTraining221`, `writeTop221`, `writeFurusato221` はJ列の決算額だけを書き込んでいます。
しかし本物原本の2-2-1には、内訳欄にも実データが残っています。

Dex確認例:

`様式２－２－１　事業別決算書（選手強化費）`

| セル | 原本値 |
|---|---:|
| `S16` | `830550` |
| `S18` | `81250` |
| `S20` | `114600` |
| `S24` | `373450` |
| `S28` | `487000` |

現コードではJ列だけを上書きしており、`S16/S18/S20/S24/S28` などの内訳欄をクリアまたは更新していません。

該当コード:

- `writeTraining221(...)`: J16/J18/J20/J22/J24/J26/J28/J30/J32のみ書込
- `writeTop221(...)`: J16/J18/J22/J24/J28/J30/J32のみ書込
- `writeFurusato221(...)`: J16/J18/J20/J28/J30/J32のみ書込

なぜ危険か:

出力ブック上で、J列の決算額は今回データなのに、右側の内訳欄は原本の過去データのまま残ります。
これは「合計は合っているが、内訳が別人/別事業の数字」という提出書類になり得ます。

P2指示でも「テンプレートのダミー値は出力前にクリアまたは上書きする」としていたため、未達です。

修正指示:

1. 2-2-1各シートの内訳欄を、出力前に必ずクリアしてください。
2. 可能なら、J列合計と同じ金額を該当カテゴリ欄に入れるか、カテゴリ別に正しく分解してください。
3. 最低限、原本の過去データが残らないことを保証してください。

推奨:

- 12A Take2では、まず「内訳欄クリア」を優先。
- カテゴリ別内訳まで正確に出す場合は、`targetCategory` 別集計が必要になるため慎重に実装。
- どちらを採用したかP3 Take2に明記。

### P2: 対象事業0件の場合、様式2-1の対象年度が古いテンプレート値のまま残る

対象:

- `ActivityController.exportAnnual(...)`
- `ExcelExportService.exportAnnualClosingBook(...)`
- `ExcelExportService.populateForm21(...)`

問題:

`ActivityController` は `year` で事業を絞り込んでいますが、`exportAnnualClosingBook` には `ids` しか渡していません。
`populateForm21` は `projects` の中から最初の `fiscalYear` を探して `E15` に書き込むため、対象事業が0件の場合は `E15` を更新しません。

その結果、例えば令和8年度として出力したのに、原本テンプレートに残っている令和7年度値がそのまま出る可能性があります。

修正指示:

1. `exportAnnualClosingBook` に対象年度を渡してください。
2. 対象事業が0件でも、`様式２－１!E15` は選択年度から正しく書いてください。
3. 0件時に年度末出力を許可するか、画面側で出力不可にするかもP3 Take2に明記してください。

Dexとしては、誤年度の帳票を出すより、0件時は出力不可にする方が安全です。

### P3: 様式2-1の担当者/TELがテンプレート固定値のまま

対象:

- `ExcelExportService.populateForm21(...)`

問題:

P2指示では `AA42/AA43/AA44/AA45` も確認対象でした。
CCはDB項目不足を理由にテンプレート値維持を選択しています。
団体名・代表者・FAX・Emailはその判断でやむを得ない面がありますが、既存アプリには `UserSettingService` があり、担当者名と電話番号は取得可能です。

このままだと、右上で操作ユーザーを切り替えても、年度末表紙の担当者/TELは原本固定値のままになります。

修正指示:

1. 少なくとも `AA42` 担当者と `AA43` TELは、既存のactive userから出せるか検討してください。
2. あえて固定値のままにするなら、Kazumax確認事項としてP3 Take2に明記してください。

これはP1/P2ほどの即時金額破壊ではありませんが、正式書類としては見落とせない残リスクです。

---

## Take2で必ず確認すること

- 2-2-1各シートの内訳欄に原本ダミー値が残っていない。
- 2-2-1のJ列合計、2-2の参照値、2-2-1内訳欄が矛盾しない。
- 対象事業0件時の挙動が安全。
- `.\mvnw.cmd -q -DskipTests compile` 成功。
- `target/classes/application.properties` が `app.version` と一致。
- 出力xlsxに `externalLinks` / `[` / `192.168.145.12` がない状態を維持。

---

## 次の担当

**CC(P3 Take2)**:

このP4_Rollbackを読んで、Cycle 12A Take2修正を行ってください。

保存先:

`docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a_take2.md`

12A Take2がOKになるまで、12Bには進まないでください。
