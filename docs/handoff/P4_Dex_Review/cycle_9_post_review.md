# [C9: Dex(P4) ⇒ CC(P3) Take2] Cycle 9 事後DIFFレビュー

## レビュー結果

**P4 NG（差し戻し）**

ただし、`ExcelExportService#populate22Summary` の金額計算ロジック本体と、様式2-2-1（選手強化費）の主要セル座標は、Dex側のテンプレート実読確認では概ね正しい。

差し戻し理由は、金額コードの主ロジックではなく、危険タスク実装後の作業ツリー安全性・検証可能性に問題が残っているため。

## 対象

事後レビュー依頼:

- `docs/handoff/P3_CC_to_Dex/cycle_9_post_review.md`

主な変更:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`

## 確認したこと

### 1. テンプレート座標

Dex側で `src/main/resources/書類.xlsx` をopenpyxlで実読し、様式2-2-1（選手強化費）を確認した。

対象シート:

- `様式２－２－１　事業別決算書（選手強化費）`

確認結果:

- J列の決算額:
  - J16: 交通費
  - J18: 宿泊費
  - J20: 旅行雑費
  - J22: 駐車料金
  - J24: 借用料
  - J26: 補償費
  - J28: 需用費
  - J30: 役務費
- 内訳:
  - S列: 成年男子 / 少年男子
  - AF列: 成年女子 / 少年女子
  - 各費目の上段が成年、下段が少年

Air実装の0-indexed座標は以下に対応しており、方向性は正しい。

- `writeSafeNumeric(sheet22, 15, 9, ...)` → J16
- `writeSafeNumeric(sheet22, 17, 9, ...)` → J18
- `writeSafeNumeric(sheet22, 19, 9, ...)` → J20
- `writeSafe(sheet22, r, 18, "")` → S列
- `writeSafe(sheet22, r, 31, "")` → AF列

### 2. 合算ロジック

OK寄り。

- J列の全体合計は、対象プロジェクト全体の合算を維持している。
- カテゴリ別内訳は `Project#getTargetCategory()` により、成年男子・少年男子・成年女子・少年女子へ分けている。
- UI上の種別選択肢もこの4カテゴリに限定されているため、通常入力ではカテゴリ漏れは起きにくい。
- 旅行雑費は既存仕様どおり `travelMiscCost × 参加人数 × travelMiscDays` で集計されている。
- `Expense#getMiscellaneousCost()` を2-2-1集計に再利用していない。

### 3. ダミー値クリア

OK寄り。

テンプレートにはS列に `830550`, `81250`, `114600`, `373450`, `487000` などのダミー値が存在する。
今回のクリア処理は、各費目の成年/少年、男女列を空白化してから、0より大きいカテゴリ別金額のみ再出力している。

この方針により、テンプレート由来の古い数値が残る問題は解消される見込み。

## 修正必須

### 1. 未追跡の検証スクリプトを作業ツリーから除外する

以下の未追跡ファイルが残っている。

- `replace.py`
- `test.py`
- `src/main/resources/templates/test.py`

特に `src/main/resources/templates/test.py` はアプリのresources配下にあり、成果物へ混入しやすい。
今回の本番変更として不要なので、削除または作業外へ退避すること。

### 2. `AGENTS.md` の文字化け/NULL混入を確認し、今回コミットへ混ぜない

`AGENTS.md` の末尾にNULL文字を含むような文字化け断片が見える。
今回のExcel金額修正とは無関係であり、誤って同時コミットしてはいけない。

今回の修正対象は原則:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- 必要なら `docs/handoff/P3_CC_to_Dex/cycle_9_post_review.md`

それ以外のマニュアル差分や過去サイクル差分は混ぜないこと。

### 3. `ExcelExportService.java` のtrailing whitespaceを除去する

`git diff --check -- src/main/java/.../ExcelExportService.java` で以下の空白警告が出ている。

- line 527
- line 537
- line 547
- line 609

機能影響はないが、危険タスクの成果物としては整えること。

### 4. compile結果をP3に記録する

Dex環境ではMaven Wrapper既知問題により再コンパイル不可。

エラー:

```text
Cannot index into a null array.
Cannot start maven from wrapper
```

CCまたはAir側で必ず以下を実行し、結果をP3に記録すること。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

### 5. 可能ならlong→intキャストを避ける

今回の実装は内部集計に `long` を使っているが、出力時に `(int)` キャストしている。
現実の金額規模では問題化しにくいが、金額計算の安全性を重視するなら `writeSafeNumeric` のlong版を追加し、`cell.setCellValue((double)value)` などで明示的に扱う方がよい。

今回の予算規模ではブロッカーにはしないが、Take2で直せるなら直すこと。

## 判断

金額計算・セル座標の主ロジックは **OK寄り**。

ただし、危険タスクであるにもかかわらず、未追跡スクリプト・resources配下の不要ファイル・無関係なマニュアル破損が残っているため、このままコミット/最終確認へ進めるのは不可。

したがって判定は **P4 NG**。

## CC / Air向け修正指示

1. `replace.py`, `test.py`, `src/main/resources/templates/test.py` を削除または作業外へ退避する。
2. `AGENTS.md` など今回対象外の差分をコミット対象から外す。文字化けが必要なら別サイクルで扱う。
3. `ExcelExportService.java` のtrailing whitespaceを除去する。
4. 可能なら `(int)` キャストを避けるlong出力へ改善する。
5. `.\mvnw.cmd -q -DskipTests compile` を実行し、結果をP3へ記録する。
6. 修正後、`docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take2.md` を作成してDexへ再提出する。

