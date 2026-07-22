[C12: Dex Practical Check => CC(P3) Take3]

# Cycle 12 実機自動確認レポート

## 判定

**NG / CC修正必要**

Kazumaxの実機確認をAI側で肩代わりするため、Dexが年度末出力フローを自動操作しました。

通常フロー（プレビュー、Excel生成、Excelシート構成、予算保存不正ペア）は概ねOKでしたが、年度末出力専用フローの「対象事業0件時リダイレクト」に実運用上の不具合を確認しました。

## サブレビュー利用判断

**使用しました。**

理由: 実機確認は画面導線、Excel生成、Excel中身、エラー導線の複数観点に分かれるため。

- デクスクルーUI担当: `/`, `/activity`, `/budget-allocations`, `/export/year/setup` のHTTP 200、主要リンク/フォーム/ボタン、テンプレートエラー痕跡を確認
- Dex本体: 年度末出力POST、プレビュー、Excelダウンロード、xlsxシート構成、sharedStrings、0件時リダイレクト、予算保存不正ペアを確認

## Findings

### P2: 年度末出力の対象事業0件時、Locationヘッダが削除され、入力画面へ戻れない可能性がある

対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `noDataRedirectUrl(...)`
- `/export/year/preview`
- `/export/year/download`

再現:

```powershell
curl.exe -i -s -X POST http://localhost:8080/export/year/preview `
  -d "year=2026&budgetTypeId=999&submitYear=8&submitMonth=7&submitDay=22&organizationNamePart1=%E5%AE%AE%E5%B4%8E%E7%9C%8C%E3%82%A2%E3%82%A4%E3%82%B9%E3%83%9B%E3%83%83%E3%82%B1%E3%83%BC&organizationNamePart2=%E9%80%A3%E7%9B%9F&representativeTitleAndName=%E4%BC%9A%E9%95%B7%20%E9%BB%92%E6%9C%A8%20%E8%AA%A0%E4%B8%80%E9%83%8E"
```

実測結果:

```text
HTTP/1.1 302
Content-Language: ja-JP
Content-Length: 0
```

`Location` ヘッダがありません。

ログ:

```text
The HTTP response header [Location] with value [...]
has been removed from the response because it is invalid
java.nio.charset.UnmappableCharacterException
```

原因:

`noDataRedirectUrl(...)` が `UriComponentsBuilder` で日本語を含むクエリを組み立てたあと、未エンコードのまま `.build().toUriString()` で返しています。

そのため、提出情報の日本語（団体名・代表者名など）がHTTPヘッダの `Location` にそのまま入り、Tomcat 11が不正ヘッダとして削除しています。

影響:

- 対象事業0件時に、本来は `/export/year/setup?...&error=no_data` へ戻るべき
- しかし `Location` が削除されるため、ブラウザ上では空の302になり、ユーザーが正しく戻れない可能性がある
- 「条件を保持して入力画面へ戻す」というCycle 12Cの目的とズレる

修正方針:

- `noDataRedirectUrl(...)` の戻り値を、HTTP Locationヘッダに入れても安全なASCII URLへエンコードしてください。
- 例: `UriComponentsBuilder... .encode(StandardCharsets.UTF_8).build().toUriString()` または同等の方法。
- Java importが必要なら `java.nio.charset.StandardCharsets` を使ってください。
- `/export/year/preview` と `/export/year/download` の両方で同じ `noDataRedirectUrl(...)` を使っているため、メソッド1箇所の修正で両方に効く想定です。

検証条件:

1. 日本語の提出情報を含んだ状態で、対象事業0件になる条件をPOSTする。
2. レスポンスが302で、`Location` に `/export/year/setup?...&error=no_data` が入る。
3. `Location` 内の日本語がpercent-encodedされている。
4. リダイレクト先を開くと、警告文が出て、提出情報が保持される。
5. `/export/year/download` 側でも同じ0件条件で壊れない。
6. `.\mvnw.cmd -q -DskipTests compile` 成功。
7. Javaコード変更なので `app.version` は `v2.4.4` へ上げる。

## OKだった確認

### 画面疎通

以下はHTTP 200で表示できました。

- `/`
- `/activity`
- `/budget-allocations`
- `/export/year/setup`

デクスクルーUI担当の確認でも、主要フォーム・リンク・ボタン・テンプレートエラーなしでした。

### 年度末出力プレビュー

`/export/year/preview` へ2026年度・全条件・提出情報つきでPOSTし、HTTP 200を確認しました。

プレビューHTMLで確認できたもの:

- `条件を編集`
- `年度末決算`
- `プレビュー`
- `Excel`
- `表紙(2-1)`
- `まとめ(2-2)`
- `選手強化(2-2-1)`
- `トップ(2-2-1)`
- `ふるさと(2-2-1)`
- `変更報告(2-3)`
- 提出日: 令和8年7月22日
- 団体名: 宮崎県アイスホッケー連盟
- 代表者職・氏名: 会長　黒木 誠一郎
- 担当者: 齋藤 和明
- TEL: 090-5288-9928
- `様式2-2の合計と、選手強化・トップ・ふるさと（2-2-1）の合計は一致しています。`

### Excel生成

`/export/year/download` へ2026年度・全条件・提出情報つきでPOSTし、xlsx生成に成功しました。

生成ファイル:

```text
tmp_cycle12_check/annual_2026_check.xlsx
```

ファイルサイズ:

```text
2,141,770 bytes
```

先頭バイト:

```text
50 4B 03 04
```

xlsxとして正常なZIP形式です。

### Excelシート構成

生成Excelは26シートでした。

主要シート:

- `様式２－１`
- `様式２－２`
- `様式２－２－１　事業別決算書（選手強化費）`
- `様式２－２－１　事業別決算書（トップチーム活用)`
- `様式２－２－１　事業別決算書（ふるさと）`
- `様式２－３`

自動生成シート:

- `2-4_...`: 4枚
- `2-5_...`: 8枚
- `2-6_...`: 8枚

### Excel内文字列・エラー

sharedStrings / worksheet XMLで確認:

- `宮崎県アイスホッケー`: あり
- `連盟`: あり
- `黒木`: あり
- `令和`: あり
- テンプレートダミー値 `830550`: なし
- `#REF!`: なし
- `#VALUE!`: なし
- `#DIV/0!`: なし
- `#NAME?`: なし
- `#N/A`: なし
- worksheet側の式エラー文字列ヒット: 0

### 予算保存の不正ペア

以下のような不正ペアPOSTは、保存されず `invalid_input` に戻りました。

```powershell
curl.exe -i -s -X POST http://localhost:8080/budget-allocations/save `
  -d "year=2026&budgetTypeIds=999&targetCategories=%E6%88%90%E5%B9%B4%E7%94%B7%E5%AD%90&allocatedAmounts=12345"
```

結果:

```text
HTTP/1.1 302
Location: http://localhost:8080/budget-allocations?year=2026&error=invalid_input
```

## CC向け修正指示

1. `ExportController.noDataRedirectUrl(...)` を、HTTP Locationヘッダとして安全なpercent-encoded URLを返すよう修正してください。
2. `/export/year/preview` と `/export/year/download` の対象0件時で、日本語提出情報を含んでも `Location` が削除されないことを確認してください。
3. Javaコード変更なので `src/main/resources/application.properties` の `app.version` を `v2.4.4` に更新してください。
4. `.\mvnw.cmd -q -DskipTests compile` を実行し、`target/classes/application.properties` も `v2.4.4` で一致することを確認してください。
5. 完了報告を `docs/handoff/P3_CC_to_Dex/cycle_12_practical_check_take3.md` に保存してください。

## Air向けUX確認はいつ行うか

AirのUX確認は、このCC修正とDex再レビューが終わった後に行うのが安全です。

理由:

- 現時点では0件時リダイレクトという実挙動の不具合がある
- Airに今見てもらうと、既知バグに引っ張られてUX判断が濁る
- CC修正後に、Airは「実際の作業者が迷わないか」「チェック手順が多すぎないか」を見るのが一番効率的

Airには、必要に応じてエアクルーを使ってもらってください。

## Air起動用トリガー（CC修正・Dex再レビューOK後に使用）

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Airへ：
Cycle 12の年度末出力について、CC修正とDex再レビューが終わった後のユーザー目線UX確認をお願いします。
docs/handoff/P4_Rollback/cycle_12_practical_check.md と、最新のP4 OKレビューを読んでください。
確認観点は「Kazumaxが実際に触ったときに迷わないか」「年度末出力、予算管理、プレビュー、Excelダウンロードの流れが自然か」「最終確認チェックリストをもっと短くできるか」です。
必要ならエアクルーを使って、画面導線・文言・チェック手順を分けて確認してください。
結果は docs/handoff/P1_Air_Blueprint/cycle_12_ux_final_check.md に保存してください。
```

