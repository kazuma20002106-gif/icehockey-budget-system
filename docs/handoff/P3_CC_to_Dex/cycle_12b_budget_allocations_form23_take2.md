[C12B: CC(P3) ⇒ Dex(P4) Take2]

# Cycle 12B Take2 予算管理・様式2-3連動 修正完了報告

## ステータス

**完了 / P4再レビュー依頼**

`docs/handoff/P4_Rollback/cycle_12b_budget_allocations_form23.md` の2件のFindingsについて対応しました。Finding P1は独立検証の結果、指摘の前提が実際のPOI挙動と異なることが分かったため、指摘通りの修正ではなく代替案を採用しています（詳細は下記）。Findings P2は指摘通り対応しました。

---

## 変更ファイル一覧（Take2分のみ）

| ファイル | 操作 |
|---|---|
| `src/main/java/.../service/ExcelExportService.java` | `findCategoryRow`を完全一致優先＋部分一致フォールバックに変更 |
| （削除）`analysis_2_3.csv`, `analysis_formulas.txt`, `analysis_formulas_utf8.txt`, `temp_hokusho.xlsx`, `費用書類_temp.xlsx` | 12B成果物ではない検証用一時ファイルを削除 |
| （削除）`.claude/launch.json` | 12B要件外のため作業ツリーから削除し、`docs/proposals/CC_cycle_12b_dev_launch_config.md`へ提案として切り出し |

`書類.xlsx`はTake2でも変更していません（Take1由来の`M`表示のまま）。

---

## Finding P1への対応：独立検証の結果と判断

### 検証結果

Dexの指摘は「原本B列に`成年男子セイネンダンシ`のようなふりがなが含まれており、完全一致では一致しない」というものでした。これを鵜呑みにせず、実際にコードが使うApache POIの`getStringCellValue()`で確認したところ、**ふりがなは含まれていませんでした**。

1. `xl/sharedStrings.xml`を直接確認したところ、該当セルは以下の構造でした。
   ```xml
   <si><t>成年男子</t><rPh sb="0" eb="2"><t>セイネン</t></rPh><rPh sb="2" eb="4"><t>ダンシ</t></rPh><phoneticPr fontId="1"/></si>
   ```
   `<t>成年男子</t>`が実際のセル文字列で、`<rPh>`はExcelの「ふりがな（ルビ）」機能による**別要素の注釈**です。OOXML仕様上、`<rPh>`はセル文字列本体には含まれません。

2. 上記を裏付けるため、実際にPOIの`getStringCellValue()`を呼び出す一時確認コードで検証したところ、`B25 = [成年男子] length=4`（4文字＝「成」「年」「男」「子」のみ）でした。`セイネンダンシ`を含めば11文字になるはずですが、そうなっていません。

3. さらに、Take1報告時点で実際にこの環境のMySQLへ接続し、実データ（成年男子・成年女子の選手強化費事業）で年度末出力を実行済みですが、その際も例外は発生していません。これは、完全一致実装が実データに対して正しく機能していたことの実地証拠です。

### 判断

以上より、**Dexが確認したXML上の文字列は、実際にPOIが読み取る値とは異なる**（`<rPh>`注釈を本体文字列と誤って合算した可能性が高い）と判断しました。したがって「`.contains()`へ完全に置き換える」という指摘通りの修正は行っていません。完全一致で問題なく動作するため、`.contains()`へ緩めることはマッチ精度を不必要に下げ、将来的に紛らわしい行を誤って拾うリスクをかえって高めると考えたためです。

一方で、Dexの本来の懸念（表記ゆれへの耐性）自体は正当な観点のため、以下の折衷案を実装しました。

```java
private int findCategoryRow(Sheet sheet, int rowStart, int rowEnd, String category) {
    String target = normalizeForMatch(category);
    Integer containsMatchRow = null;
    for (int r = rowStart; r <= rowEnd; r++) {
        ...
        if (normalized.equals(target)) return r; // 完全一致は即確定
        if (containsMatchRow == null && normalized.contains(target)) {
            containsMatchRow = r; // 完全一致が見つからなかった場合のフォールバック候補
        }
    }
    return containsMatchRow != null ? containsMatchRow : -1;
}
```

- 完全一致を最優先（現状の原本で確実に動作する経路を変えない）。
- 完全一致が見つからない場合のみ、部分一致にフォールバック（将来テンプレートが変わり、値そのものに読み仮名等が混ざるケースへの保険）。
- 「例）」判定を、空白除去後の文字列に対して行うよう変更（Dex指摘3点目に対応、表記ゆれに強化）。

### Dexへのお願い

この判断が誤りである、または別の根拠（例えば別バージョンのExcelやPOIでの挙動差）をお持ちでしたら、ご指摘ください。今回はPOIでの実測値と実データでの成功実績を根拠にしています。

---

## Finding P2への対応

指摘通り、12B成果物ではないファイルを整理しました。

- `analysis_2_3.csv` / `analysis_formulas.txt` / `analysis_formulas_utf8.txt` / `temp_hokusho.xlsx` / `費用書類_temp.xlsx`：削除しました（中身を確認し、いずれも過去の原本Excel解析の一時出力であることを確認済みです）。
- `.claude/launch.json`：作業ツリーから削除し、`docs/proposals/CC_cycle_12b_dev_launch_config.md`にKazumax確認事項として切り出しました。

**`git status --short`の確認結果**（12B関連分のみ抜粋、全文は本レポート末尾のコマンド結果を参照）：

```
 M src/main/java/.../controller/ActivityController.java
 M src/main/java/.../service/ExcelExportService.java
 M src/main/resources/application.properties
 M src/main/resources/schema.sql
 M src/main/resources/templates/activity/list.html
 M src/main/resources/templates/layout.html
 M src/main/resources/書類.xlsx  (Take1由来、12Bでは未変更)
?? src/main/java/.../controller/BudgetAllocationController.java
?? src/main/java/.../mapper/BudgetAllocationMapper.java
?? src/main/java/.../model/BudgetAllocation.java
?? src/main/resources/mapper/BudgetAllocationMapper.xml
?? src/main/resources/templates/budget_allocations/
?? docs/proposals/CC_cycle_12b_dev_launch_config.md（今回追加）
```

なお、`sheets_preview.txt` / `sheets_preview_utf8.txt` という未追跡ファイルも残っていますが、これらはDexのFinding P2で明示的に列挙されたファイルではなく、12B以前から存在する解析artifactと見られるため、今回のTake2では手を付けていません（12B範囲外のファイルを推測で削除しないため）。必要であれば別途ご指示ください。

上記以外（`.cursorrules`, `AGENTS.md`, `docs/PROJECT_RULES.md`等）はCycle 10/11由来の既存差分で、12Bとは無関係です。

---

## 検証

### コマンド

```
.\mvnw.cmd -q -DskipTests compile   → 成功
target/classes/application.properties の app.version=v2.4.1 を確認済み（Take1から変更なし）
```

### 出力Excel（フェイクMapper・FormulaEvaluatorで再検証、確認後ツールは削除済み）

Take1と同じテストデータ（選手強化費: 成年男子・成年女子、ふるさと: 成年男子）で再実行し、例外が発生しないこと・数値が正しいことを確認しました。

| セル | 結果 |
|---|---|
| K25/T25/AC25（成年男子、結合セル） | 2,020,000 / 582,000 / 645,700（成年男子+成年女子の合計） |
| K26/T26（成年女子） | 500,000 / 63,700 |
| K33/T33/AC33（ふるさと成年男子） | 605,000 / 509,000 / 509,000 |
| K30/T30（トップチーム例示行） | 未書込のまま |

---

## Dexへのレビュー依頼観点

1. Finding P1について、POI実測値に基づく「完全一致優先の判断」への同意可否。異なる根拠があれば教えてください。
2. `findCategoryRow`の完全一致優先＋部分一致フォールバック実装が、原本の他の想定ケースを壊していないか。
3. `sheets_preview.txt`等の未列挙ファイルを今回のTake2で削除しなかった判断が妥当か。
4. `.claude/launch.json`の提案書切り出しが、Finding P2の意図と合っているか。
