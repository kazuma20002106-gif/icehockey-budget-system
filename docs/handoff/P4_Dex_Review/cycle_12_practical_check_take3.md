[C12: Dex(P4) => Kazumax/Air]

# Cycle 12 実機自動確認 Take3 P4レビュー

## 判定

**OK**

`noDataRedirectUrl(...)` のpercent-encoding対応は、DexのTake3差戻し指摘を満たしています。
Cycle 12年度末出力専用フローの対象事業0件時リダイレクト不具合は、この修正で解消済みと判断します。

## サブレビュー利用判断

**使用。**

理由: Take3で扱う範囲は狭いものの、対象がリダイレクト・日本語percent-encoding・条件保持・preview/download両導線にまたがるため。

- デクスクルー: 静的確認。`noDataRedirectUrl(...)` の呼び出し元、`.encode(...)` の位置、既存パラメータ保持、version同期を確認
- Dex本体: 差分確認、compile、ローカルHTTP実測、最終OK/NG判断を実施

デクスクルーからP1/P2/P3相当の追加懸念はありませんでした。最終判定はDexが統合して行いました。

## Findings

**なし。**

差し戻し事項はありません。

## 確認内容

### 1. 差分範囲

`git show HEAD` で確認したTake3コミット:

- `57e756e [v2.4.4] Cycle 12 実機自動確認 Take3: 0件時Locationヘッダの日本語エンコード修正`

変更ファイル:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `src/main/resources/application.properties`
- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P3_CC_to_Dex/cycle_12_practical_check_take3.md`

Take3目的外のJavaロジック変更は見当たりません。

### 2. `noDataRedirectUrl(...)` の修正内容

OKです。

`UriComponentsBuilder.fromPath(...)` でパスとクエリを組み立て、全パラメータ追加後に以下を実行しています。

```java
.encode(java.nio.charset.StandardCharsets.UTF_8)
.build()
.toUriString();
```

日本語の団体名・代表者名・条件文字列は、`Location` ヘッダに入る前にpercent-encodedされます。
元指摘のTomcatによる `Location` ヘッダ削除リスクに対する修正として妥当です。

### 3. preview/download 両方に効く構造

OKです。

- `/export/year/preview` の0件時: `return "redirect:" + noDataRedirectUrl(...)`
- `/export/year/download` の0件時: `response.sendRedirect(noDataRedirectUrl(...))`

どちらも同じ `noDataRedirectUrl(...)` を呼ぶため、helper 1箇所の修正で両方に反映されます。

### 4. バージョン同期

OKです。

- `src/main/resources/application.properties`: `app.version=v2.4.4`
- `target/classes/application.properties`: `app.version=v2.4.4`

### 5. compile

OKです。

Dex側でも `.\mvnw.cmd -q -DskipTests compile` を実行し、成功を確認しました。

補足:
最初のsandbox内実行はMaven親POM解決のネットワーク制限で失敗しました。
同じコマンドを権限付きで再実行し、成功しています。

### 6. ローカルHTTP実測

OKです。

Dex側でローカル起動後、以下を確認しました。

#### `/export/year/preview` 0件条件

日本語提出情報を含むPOSTで、以下を確認。

```text
HTTP/1.1 302
Location: http://localhost:8080/export/year/setup?year=2026&budgetTypeId=999&submitYear=8&submitMonth=7&submitDay=22&organizationNamePart1=%E5%AE%AE%E5%B4%8E%E7%9C%8C%E3%82%A2%E3%82%A4%E3%82%B9%E3%83%9B%E3%83%83%E3%82%B1%E3%83%BC&organizationNamePart2=%E9%80%A3%E7%9B%9F&representativeTitleAndName=%E4%BC%9A%E9%95%B7%20%E9%BB%92%E6%9C%A8%20%E8%AA%A0%E4%B8%80%E9%83%8E&error=no_data
```

修正前に発生していた `Location` ヘッダ欠落は再現しませんでした。

#### `/export/year/download` 0件条件

同じ日本語提出情報を含むPOSTで、`/export/year/preview` と同等のpercent-encoded `Location` ヘッダが返ることを確認しました。

#### リダイレクト先

上記 `Location` 先の `/export/year/setup` を開き、以下を確認しました。

- 「選択した年度・条件に該当する事業がないため、プレビュー・出力できません。条件を確認してください。」の警告表示あり
- 団体名: `宮崎県アイスホッケー`
- 団体名2: `連盟`
- 代表者職・氏名: `会長 黒木 誠一郎`
- 画面バージョン表示: `v2.4.4`

#### 正常系

`budgetTypeId` を外した通常条件で `/export/year/preview` にPOSTし、HTTP 200で年度末決算ファイルプレビューが表示されることを確認しました。

## 残リスク

このP4 OKは、Cycle 12 Take3のリダイレクト修正範囲に対するものです。

以下は今回の対象外で、Cycle 13候補として扱います。

- `ActivityController` の旅行雑費表示合算漏れ
- legacy `/export` の2-2プレビュー合算漏れ
- `ExportController.preview()` の `exList.get(0)` による複数Expense過小集計

詳細は `docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md` を参照してください。

## 次の流れ

Cycle 12はP4 OK。
次は `docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md` のAir起票トリガーに進めます。
