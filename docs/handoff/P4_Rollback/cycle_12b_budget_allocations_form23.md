[C12B: Dex(P4) => CC(P3) Take2]

# Cycle 12B 予算管理・様式2-3連動 P4レビュー

## 判定

**NG / CC Take2差し戻し**

ビルドとバージョン同期は成功しています。

- `.\mvnw.cmd -q -DskipTests compile`: 成功
- `src/main/resources/application.properties`: `app.version=v2.4.1`
- `target/classes/application.properties`: `app.version=v2.4.1`

ただし、様式2-3の行検索ロジックがDex指示と原本構造に合っておらず、実データがある年度末出力で例外停止する可能性が高いです。金額・Excel出力の根幹なので、12Cへ進む前に必ずTake2で修正してください。

## Findings

### P1: 様式2-3のB列検索が完全一致になっており、原本のふりがな付きセルに一致しない

対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `findCategoryRow`
- `normalizeForMatch`

現在の実装:

```java
if (normalizeForMatch(raw).equals(target)) return r;
```

Dex指示書では、原本B列にふりがなが混ざるため「完全一致は禁止」「対象区分名を含む行を候補」と指定していました。

`docs/handoff/P2_Dex_to_CC/cycle_12b_budget_allocations_form23_instructions.md`:

- 原本のB列にはふりがな等が混ざっている
- 対象区分名を含む行を候補にする
- `例）` / `例)` 行は除外する

Dex側で `src/main/resources/書類.xlsx` の `様式２－３` をXML確認した結果、実際のB列は以下です。

| 行 | B列 |
|---:|---|
| 25 | `成年男子セイネンダンシ` |
| 26 | `成年女子セイネンジョシ` |
| 27 | `少年男子ショウネンダンシ` |
| 28 | `少年女子ショウネンジョシ` |
| 30 | `例）少年男子レイショウネンダンシ` |
| 31 | `例）少年女子レイショウネンジョシ` |
| 33 | `成年男子セイネンダンシ` |

つまり、現在の完全一致では `成年男子` と `成年男子セイネンダンシ` が一致せず、`findCategoryRow` が `-1` を返します。成年男子などに内示額または決算額があると、`writeForm23Section` が `IllegalStateException` を投げ、年度末出力が止まります。

#### Take2修正指示

1. `findCategoryRow` は、正規化後のB列が正規化後カテゴリを **含む** 場合に一致扱いにしてください。
   - 例: `normalizeForMatch(raw).contains(target)`
2. `例）` / `例)` 行の除外は維持してください。
3. 可能なら `例）` 判定も空白除去後に行い、`例 ）` などの表記揺れに少し強くしてください。
4. 検証では、原本B列が `成年男子セイネンダンシ` の状態で、`成年男子` が25行に一致することを確認してください。
5. ふるさと33行の `成年男子セイネンダンシ` にも一致することを確認してください。
6. トップチーム30〜31行の `例）少年男子...` / `例）少年女子...` は、引き続き一致対象外であることを確認してください。

### P2: 検証用・開発用の未追跡ファイルが残っている

`git status --short` で、12B実装ファイル以外に以下の未追跡ファイルが残っています。

- `.claude/`
- `analysis_2_3.csv`
- `analysis_formulas.txt`
- `analysis_formulas_utf8.txt`
- `temp_hokusho.xlsx`
- `費用書類_temp.xlsx`

P3報告書では `.claude/launch.json` を「今後の起動確認用」として作成した旨が書かれていますが、今回の12B要件には含まれていません。検証用CSV/TXT/XLSXも成果物ではありません。

#### Take2修正指示

1. 12B実装に必要なファイルだけ残してください。
2. 検証用・一時ファイルは削除してください。
3. `.claude/launch.json` を残す必要がある場合は、12B要件外の開発補助ファイルとして `docs/proposals/` に提案を書き、Kazumax判断待ちにしてください。今回の12B本体には混ぜないでください。
4. Take2報告書には、`git status --short` で不要な未追跡ファイルが残っていないことを明記してください。

## 良かった点

- `budget_allocations` は `CREATE TABLE IF NOT EXISTS` で追加され、破壊的DDLは見当たりません。
- `allocated_amount` は `BIGINT`、Java側も `Long` / `long` で扱っています。
- 保存処理は、負数・数値変換不可が1件でもあれば保存前に止める構造です。
- `app.version` は `v2.4.1` へ更新され、compile後の `target/classes` と同期しています。
- 様式2-3のAC25:AK28が結合セルであることを確認し、AC25へセクション合計を一度だけ書く判断は原本構造として妥当です。

## Take2で必ず確認すること

- [ ] `成年男子` が `成年男子セイネンダンシ` に一致する
- [ ] `成年女子` が `成年女子セイネンジョシ` に一致する
- [ ] `少年男子` が `少年男子ショウネンダンシ` に一致する
- [ ] `少年女子` が `少年女子ショウネンジョシ` に一致する
- [ ] ふるさと33行の `成年男子セイネンダンシ` に一致する
- [ ] `例）少年男子...` / `例）少年女子...` には一致しない
- [ ] K列・T列・AC列以外に書き込んでいない
- [ ] 12Aの2-1/2-2/2-2-1/2-4/2-5/2-6出力が壊れていない
- [ ] `.\mvnw.cmd -q -DskipTests compile` が成功する
- [ ] `src/main/resources/application.properties` と `target/classes/application.properties` の `app.version` が一致する
- [ ] 不要な未追跡ファイルが残っていない

## 次の担当

**CC(P3 Take2)**:

このP4_Rollbackを読んで、Cycle 12B Take2修正を行ってください。

Take2完了後は、次へ報告してください。

`docs/handoff/P3_CC_to_Dex/cycle_12b_budget_allocations_form23_take2.md`

12B Take2がDex(P4) OKになるまで、12Cには進まないでください。
