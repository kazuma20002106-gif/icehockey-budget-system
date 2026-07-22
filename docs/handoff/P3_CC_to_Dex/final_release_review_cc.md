[Release Review: CC(P3) => Dex(P4) Final Integration Review]

# 最終出荷レビュー CC視点（実装・実機・compile・Excel出力・git状態）

Air視点のレビュー（`docs/handoff/P1_Air_Blueprint/final_release_review_air.md`、判定「デプロイ準備 完了」）を受け、CC視点で実装・実機・compile・Excel出力・git状態の最終検品を実施した。目的は新機能追加ではなく、フェーズ2（VPS本番環境構築）へ進む前の最終検品。

対象HEAD: `0026794`（Cycle 15 Take2完了時点）。

## 判定

**CC視点: 異常なし。デプロイ前提として問題ない。**

ただし、年度末決算Excelの様式2-2内に1箇所、grepベースのダミー値チェックだけでは「異常あり」と見えてしまうセルを発見したため、詳細調査のうえ結果を報告する（詳細は「6. 発見事項」参照）。実害はないと判断した。

## 1. `git status --short --untracked-files=all` の確認

レビュー開始時点:

```text
 M docs/handoff/CURRENT_STATUS.md
?? docs/handoff/P1_Air_Blueprint/cycle_16_next_phase_planning.md
?? docs/handoff/P1_Air_Blueprint/final_release_review_air.md
?? docs/handoff/P1_Air_Blueprint/phase2_server_deployment.md
?? docs/handoff/P4_Dex_Review/cycle_15_policy_and_cleanup_take2.md
```

未追跡4件はいずれも内容確認済みの正式なhandoff記録（Air最終出荷レビュー、Cycle 16 Blueprint、フェーズ2サーバー構築Blueprint、DexのCycle 15 Take2 P4 OKレビュー）。ダミー・一時ファイルの類ではないため、コミット対象として取り込む。取り込み後、本報告書・CURRENT_STATUS更新分と合わせてコミットし、`git status --short --untracked-files=all` が出力なし（クリーン）になることを確認する（結果は末尾「10. 最終git status」参照）。

## 2. `app.version` のsrc/target一致確認

```powershell
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

```text
src/main/resources/application.properties: app.version=v2.4.8
target/classes/application.properties: app.version=v2.4.8
```

Cycle 15 Take2完了時点の最新バージョンで一致。今回のレビューはコード変更を伴わないため、バージョンは更新していない。

## 3. compile確認

```powershell
.\mvnw.cmd -q -DskipTests compile
```

成功（エラーなし）。事前に`tasklist`で`java.exe`が起動していないことを確認したうえで実行した。

## 4. `/activity?year=2026` 確認

ローカルで`.\mvnw.cmd spring-boot:run`を起動し、ブラウザで確認した。

- 事業件数: **8件**
- 延べ参加人数: **30名**
- 決算書計上額: **481,179円**
- ヘッダー・フッターとも「決算書計上額」表記、「※個人雑費はこの合計に含めず、様式2-6で確認します。」の注記あり
- ブラウザコンソールにエラーなし

Cycle 15完了時点から一切変化がないことを確認した。

## 5. legacy 2-2 / 2-6 preview、年度末出力previewの疎通確認

| 確認対象 | 結果 |
|---|---|
| `POST /export/preview`（`exportType=2-2`、2026年度8事業選択） | HTTP 200。総合計 **481,179円**（`/activity`の決算書計上額と一致） |
| `POST /export/preview`（`exportType=2-6`、事業単体） | HTTP 200。個人明細行が表示される |
| `GET /export/year/setup` | HTTP 200 |
| `POST /export/year/preview`（2026年度・全条件） | HTTP 200。「様式2-2の合計と、選手強化・トップ・ふるさと（2-2-1）の合計は一致しています。」の整合メッセージを確認 |

いずれも壊れていない。

## 6. Excel出力の確認（発見事項を含む）

### legacy `exportType=2-2` ダウンロード

```powershell
POST /export/download (exportType=2-2, 8事業選択)
```

- HTTP 200、サイズ1,963,259バイト、xlsx形式（PKヘッダー）を確認。
- 展開してシートXML全体を`830550`（既知のテンプレートダミー値）と`#REF!`/`#VALUE!`/`#DIV/0!`/`#NAME?`/`#N/A`（式エラー文字列）でgrepし、**該当なし**を確認した。

### 年度末決算ファイル（`/export/year/download`）ダウンロード

```powershell
POST /export/year/download (2026年度・全条件)
```

- HTTP 200、サイズ2,141,769バイト、xlsx形式を確認（Cycle 12〜14で確認済みの実測サイズとほぼ一致）。
- シート数35（様式2-1/2-2/2-2-1×3/2-3＋2-4/2-5/2-6の自動生成シート群）を確認。
- `#REF!`等の式エラー文字列は全シートで**該当なし**。
- **`830550`が1箇所ヒットした**（詳細は次項）。

### 発見事項の詳細調査: 様式2-2シート内の`830550`

`xl/worksheets/sheet2.xml`（様式２－２）のセル`Q17`に、以下の式とキャッシュ値を発見した。

```xml
<c r="Q17" s="181"><f>'様式２－２－１　事業別決算書（選手強化費）'!J16</f><v>830550</v></c>
```

これは「様式２－２－１　事業別決算書（選手強化費）」シートのJ16セルを参照するクロスシート式で、キャッシュされた表示値が`830550`になっている。一見、テンプレートのダミー値がそのまま出力されているように見える。

調査のため、参照先である`sheet3.xml`（選手強化費2-2-1シート）のJ16セルを直接確認したところ、以下の通り**正しい実データ**が書き込まれていた。

```xml
<c r="J16" s="333" t="n"><v>37519.0</v></c>
```

`37519`は、Cycle 12〜14の検証で確認済みの2026年度・選手強化費カテゴリの実際の交通費合計と一致する正しい値である。

つまり、`Q17`のキャッシュ値`830550`は、**参照元セルの値が更新された際に再計算されずに残った古いキャッシュ**であり、参照元のJ16自体は正しい値に書き換わっている。

この種のクロスシート式キャッシュのズレは、ファイルを開いたアプリケーション側で強制的に全式再計算が行われれば表示上は問題にならない。実際に、ワークブック全体の設定を確認したところ、

```xml
<calcPr calcId="145621" fullCalcOnLoad="true"/>
```

と`fullCalcOnLoad="true"`が設定されていることを確認した。これは、Excel等でこのファイルを開いた瞬間に全セルの式が強制的に再計算されることを意味する設定であり、`ExcelExportService`側で`workbook.setForceFormulaRecalculation(true)`を設定していることに対応する（Cycle 12以降のレビューで繰り返し確認されてきた仕組み）。

したがって、**実際に依頼主がExcelでこのファイルを開いた際に表示される値は、キャッシュの830550ではなく、再計算された正しい37,519円になる**と判断した。同じ`830550`はlegacy `2-2`側のExcel（クロスシート式を使わず直接値を書き込む方式）には一切出現しておらず、`fullCalcOnLoad="true"`もそちらで確認済みである。

### この発見の位置づけ

- **実際のユーザー体験に影響する不具合ではないと判断した**（表計算ソフトで開けば正しい値が表示されるため）。
- ただし、`grep 830550`のような機械的なダミー値チェックだけでは「異常あり」と誤判定されうるセルが年度末Excelに存在することは事実であり、将来の監査担当（Dexの回帰チェック等）が同じ現象に遭遇した際に混乱しないよう、本報告書に詳細な調査手順（参照先セルの実値確認、`fullCalcOnLoad`確認）を残す。
- コードの修正は行っていない（今回は検品目的のサイクルであり、無断修正はしない方針のため）。POI側でクロスシート式のキャッシュ値も正しい値で書き込む対応（例: セル書き込み後に明示的に式評価してキャッシュを更新する等）は、次サイクル以降の改善候補として検討の余地がある。

## 7. Cycle 12〜15で触った金額・帳票・個人雑費・旅行雑費まわりの異常有無

再監査ではなく、既存の確定済みレビュー結果と本レビューでの再疎通確認を突き合わせた結果、異常は見つからなかった。

- **Cycle 12（年度末出力導線）**: `/export/year/setup`→`preview`→`download`の一連の流れ、0件時のpercent-encodingリダイレクトともに、本レビューで再疎通確認し問題なし。
- **Cycle 13（旅行雑費・複数Expense）**: legacy 2-2の総合計481,179円が`/activity`の決算書計上額と一致することを再確認。旅行雑費と個人雑費が混同されていないことは、Cycle 13/14/15で繰り返しコード・実データ検証済みで、本レビューでも該当コード（`ActivityController.java`/`ExportController.java`/`ExcelExportService.java`）に差分がないことを`git status`で確認済み。
- **Cycle 14（全体監査）**: 発見済みの「個人雑費が様式2-2系合計と`/activity`合計で構造的に不一致」という論点は、Cycle 15で意図的な仕様（決算書計上額から個人雑費除外）として解決済み。
- **Cycle 15（個人雑費の扱い・編集保存保持）**: 編集保存時に個人雑費・受領日が消えない修正がTake2で完了し、Dex(P4)のOKレビュー済み。本レビューでは`activity/form.html`・`ActivityController.java`に追加差分がないことを確認。

## 8. Excel出力全体の健全性まとめ

| 確認項目 | 結果 |
|---|---|
| legacy 2-2 Excel: ダミー値`830550` | なし |
| legacy 2-2 Excel: 式エラー文字列 | なし |
| 年度末Excel: ダミー値`830550` | Q17に1箇所あり。参照元は正しい値に更新済み、`fullCalcOnLoad`により実害なしと確認 |
| 年度末Excel: 式エラー文字列 | なし |
| 年度末Excel: シート数 | 35（想定通り） |

## 9. 今回の作業範囲

Java・HTML・mapper・schema・Excelテンプレート本体はいずれも変更していない。`docs/handoff/`配下の正式記録の取り込みと、本報告書・`CURRENT_STATUS.md`の更新のみ。`app.version`は据え置き（コード変更なしのため）。

## 10. 最終 `git status --short --untracked-files=all`

本報告書とCURRENT_STATUS更新、および冒頭で確認した4件の正式handoff記録をコミットした後、出力なし（working tree clean）であることを確認する。commit hash・push結果は本ファイルのコミット後に追記する。

## 次への合図

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Dexへ：
Air視点(異常なし)・CC視点(異常なし、ただし年度末Excelのクロスシート式キャッシュに関する1件の発見事項あり)の最終レビューが揃いました。
docs/handoff/P1_Air_Blueprint/final_release_review_air.md と docs/handoff/P3_CC_to_Dex/final_release_review_cc.md を読んで、最終統合レビュー(デプロイ判定)をお願いします。
```
