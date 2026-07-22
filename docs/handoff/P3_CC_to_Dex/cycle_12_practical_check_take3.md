[C12: CC(P3) => Dex(P4) Practical Check Take3]

# Cycle 12 実機自動確認 Take3 修正完了報告

`docs/handoff/P4_Rollback/cycle_12_practical_check.md` のP2指摘（対象事業0件時、日本語提出情報を含む`Location`ヘッダがTomcatに削除される問題）に対応した。

## 変更したファイル

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
  - `noDataRedirectUrl(...)`（272〜290行付近）の末尾に `.encode(java.nio.charset.StandardCharsets.UTF_8)` を追加し、`UriComponentsBuilder`が組み立てるURLをpercent-encodedな安全な文字列にしてから`Location`ヘッダへ渡すようにした。
  - `/export/year/preview`（`redirect:`経由）と `/export/year/download`（`response.sendRedirect(...)`経由）の両方がこの同じメソッドを呼んでいるため、1箇所の修正で両方に反映される。

## app.version

`v2.4.4`（Javaコード変更のため更新。指示通り`v2.4.3`→`v2.4.4`）

## 実行した検証コマンドと結果

事前準備として、Dexの実機自動確認セッションが起動したままだったbudget-system devサーバー（PID 7392/13736、`mvnw spring-boot:run`とその子javaプロセス）を停止してからcompileした（無関係な他プロセスではなく、本タスクで変更する本アプリのプロセスのため）。

```powershell
.\mvnw.cmd -q -DskipTests compile
# → 成功（エラーなし）

Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
# → 両方とも app.version=v2.4.4 で一致
```

検証条件1〜5（Dex指定の再現手順どおり、`.\mvnw.cmd spring-boot:run`でローカル起動して確認）:

```powershell
curl.exe -i -s -X POST http://localhost:8080/export/year/preview `
  -d "year=2026&budgetTypeId=999&submitYear=8&submitMonth=7&submitDay=22&organizationNamePart1=%E5%AE%AE%E5%B4%8E%E7%9C%8C%E3%82%A2%E3%82%A4%E3%82%B9%E3%83%9B%E3%83%83%E3%82%B1%E3%83%BC&organizationNamePart2=%E9%80%A3%E7%9B%9F&representativeTitleAndName=%E4%BC%9A%E9%95%B7%20%E9%BB%92%E6%9C%A8%20%E8%AA%A0%E4%B8%80%E9%83%8E"
```

結果:

```text
HTTP/1.1 302
Location: http://localhost:8080/export/year/setup?year=2026&budgetTypeId=999&submitYear=8&submitMonth=7&submitDay=22&organizationNamePart1=%E5%AE%AE%E5%B4%8E%E7%9C%8C%E3%82%A2%E3%82%A4%E3%82%B9%E3%83%9B%E3%83%83%E3%82%B1%E3%83%BC&organizationNamePart2=%E9%80%A3%E7%9B%9F&representativeTitleAndName=%E4%BC%9A%E9%95%B7%20%E9%BB%92%E6%9C%A8%20%E8%AA%A0%E4%B8%80%E9%83%8E&error=no_data
Content-Language: ja-JP
```

- ✅ 条件2: 302で`Location`に`/export/year/setup?...&error=no_data`が入っている
- ✅ 条件3: `Location`内の日本語（団体名・代表者名）がpercent-encoded（`%E5%AE%AE...`等）されている。修正前のような`UnmappableCharacterException`ログ・ヘッダ欠落は発生しなかった

同じ条件で`/export/year/download`にもPOSTし、同様に`Location`ヘッダがpercent-encoded付きで返ることを確認した（条件5）。

- ✅ 条件4: ブラウザで上記`Location`先を開き、「選択した年度・条件に該当する事業がないため、プレビュー・出力できません。条件を確認してください。」という警告文が表示され、提出日（令和8年7月22日）・団体名（宮崎県アイスホッケー／連盟）・代表者職氏名（会長　黒木 誠一郎）がフォームに保持されていることを確認した。ブラウザコンソールにエラーなし

回帰確認として、`budgetTypeId`を外した通常条件（対象事業あり）で`/export/year/preview`にPOSTし、`HTTP 200`が返ることも確認した（`.encode(...)`追加による正常系への副作用なし）。

## resources混入確認結果

今回は`ExportController.java`のみの変更で、`resources`配下のテンプレート・静的ファイルには触れていない。前回Take2硬化時点で混入なしを確認済みのため、今回は追加確認を省略した。

## Cycle 12本体ファイルの取り込み漏れ確認結果

今回変更したのは`ExportController.java`と`application.properties`の2ファイルのみで、いずれも既にHEADに存在する追跡済みファイル。新規未追跡ファイルの発生はない。

## 残リスク

- Dexの`cycle_12_practical_check.md`に記載された残りのOK項目（画面疎通・プレビュー・Excel生成・Excelシート構成・予算保存不正ペア）は今回変更していないため、Take3の影響を受けない。
- `docs/handoff/P3_CC_to_Dex/cycle_12_realmachine_check_and_bug_report_for_dex.md`・`docs/proposals/CC_activity_list_travel_misc_total_bug.md`で報告済みの「旅行雑費の画面プレビュー合算漏れ」バグは、今回のTake3の対応範囲外（別件）。

## 次への合図

```text
CCがCycle 12実機自動確認のTake3修正（noDataRedirectUrlのpercent-encoding対応）を完了しました。v2.4.4です。
docs/handoff/P3_CC_to_Dex/cycle_12_practical_check_take3.md を読んで、事後レビュー（P4）をお願いします。
```
