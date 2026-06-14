# [C5: Dex(P4) => CC(P3) Take2]

## レビュー結果

NGです。Cycle 5 の大部分は実装されていますが、P1/P2の帳票要件に対して未達があります。特に様式2-5の宿泊あり期間表示が未実装で、様式2-6の合計表示にも整合性リスクがあります。以下を修正してください。

## 対象

- P2指示書: `docs/handoff/P2_Dex_to_CC/cycle_5.md`
- P3報告書: `docs/handoff/P3_CC_to_Dex/cycle_5.md`
- レビュー対象コミット: `71c4885` / `e2ef8c9`

## 修正指示

### 1. 様式2-5の事業実施日を、宿泊ありの場合に期間表示へ直す

現在の実装では、宿泊費がある参加者がいても `populate25()` で常に単日表示になっています。

該当箇所:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `populate25()`
- 現在: `writeSafe(sheet, 5, 2, formatJapaneseDate(project.getEventDate()));`

P2要件:

- 宿泊なし: `令和X年Y月Z日`
- 宿泊あり: `令和X年Y月Z日～W日`

修正方針:

- `hasAccommodation` を事業実施日の書き込み前に計算してください。
- 宿泊費が1円以上の参加者がいる場合は、現行モデルに泊数がないため、P2どおり `eventDate.plusDays(1)` を終了日として使ってください。
- 終了日の出力は `～W日` でよいです。月跨ぎの可能性がある場合は `～M月W日` にしても構いませんが、P2の形式に寄せるなら同月は `～W日`、月跨ぎは `～M月W日` を推奨します。

実装例:

```java
boolean hasAccommodation = participants.stream().anyMatch(p ->
        p.getExpense() != null && nz(p.getExpense().getAccommodationCost()) > 0);

if (project.getEventDate() != null) {
    String eventDateText = formatJapaneseDate(project.getEventDate());
    if (hasAccommodation) {
        LocalDate endDate = project.getEventDate().plusDays(1);
        if (endDate.getMonthValue() == project.getEventDate().getMonthValue()) {
            eventDateText += "～" + endDate.getDayOfMonth() + "日";
        } else {
            eventDateText += "～" + endDate.getMonthValue() + "月" + endDate.getDayOfMonth() + "日";
        }
    }
    writeSafe(sheet, 5, 2, eventDateText);
}
```

注意:

- `hasAccommodation` の定義は、宿泊対象者ヘッダー/参加者 `〇` 印字と同じ条件にしてください。
- 同じ `hasAccommodation` を二重定義しないよう整理してください。

### 2. 様式2-5の宿泊対象者印字を `〇` に統一する

現在の実装はコメントでは `〇` と書いていますが、実際には `○` を出しています。

該当箇所:

```java
writeSafe(sheet, r, 7, accommodated ? "○" : "");
```

P1/P2では `〇` と明記されているため、以下に統一してください。

```java
writeSafe(sheet, r, 7, accommodated ? "〇" : "");
```

### 3. 様式2-6の雑費合計と旅費合計の整合を取る

現在の実装:

```java
writeSafeNumeric(sheet, 39, 27, 0);
writeSafeNumeric(sheet, 39, 37, totalTransport + totalAccommodation + totalMisc);
```

このままだと、帳票上は雑費合計が `0` に見えるのに、旅費合計には `totalMisc` が含まれます。利用者から見ると、明細合計と総計が一致しない帳票になります。

修正方針は以下のどちらかにしてください。

推奨:

- 雑費欄・雑費合計にも `totalMisc` を数値で表示する。
- 旅費合計は `totalTransport + totalAccommodation + totalMisc` のまま。
- これにより「実際の合計金額」と帳票上の内訳が一致します。

代替:

- 雑費欄を引き続き `-` / `0` とするなら、旅費合計にも `totalMisc` を含めない。
- ただし、P2では「実際の合計金額」を優先しているため、推奨案を採用してください。

修正例:

```java
writeSafeNumeric(sheet, r, 27, mc);
...
writeSafeNumeric(sheet, 39, 27, totalMisc);
writeSafeNumeric(sheet, 39, 37, totalTransport + totalAccommodation + totalMisc);
```

注意:

- 2-6の明細行で雑費欄を数値化する場合、余り行クリアも現状どおりで構いません。
- P3報告書には、雑費欄を `-` 維持にしたのか数値表示にしたのかを明記してください。

### 4. 検証とバージョン更新

Take2修正後に以下を確認してください。

- `.\mvnw compile` が `BUILD SUCCESS`。
- `src/main/resources/application.properties` と `target/classes/application.properties` がどちらも `app.version=v1.8.11`。
- 様式2-5で宿泊費が1円以上の参加者がいる場合、事業実施日が `令和X年Y月Z日～W日` になる。
- 様式2-5の宿泊対象者欄が `〇` で印字される。
- 様式2-6で雑費明細、雑費合計、旅費合計の計算が帳票上で矛盾しない。
- Cycle 5の他の実装、特にプレビュー導線・月別フィルター・2-4相方自動連行が壊れていない。

## 完了時の必須作業

1. `app.version=v1.8.11` に更新する。
2. `.\mvnw compile` を実行する。
3. `target/classes/application.properties` の `app.version=v1.8.11` を確認する。
4. 変更をコミットする。
5. `git push origin main` を実行する。
6. P3 Take2 報告書を `docs/handoff/P3_CC_to_Dex/cycle_5_take2.md` に作成する。
7. Kazumax向け報告には「GitHubへプッシュしました」と明記する。

## 次の担当への合図（コピー用）

```text
デクスから差し戻しがあったよ。最新のファイルを読んで修正して！
```
