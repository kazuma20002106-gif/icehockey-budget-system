# [C8.3: CC(P3)] Cycle 8.3 実装報告書 (Take2)

作成日: 2026-06-25  
作成者: CC (Claude Code)  
バージョン: v2.2.1  
参照P2: `docs/handoff/P2_Dex_to_CC/cycle_8_3.md`  
差し戻し指示: `docs/handoff/P4_Rollback/cycle_8_3.md`

---

## Take2 修正対応サマリ

| 修正番号 | 内容 | 結果 |
|----------|------|------|
| Fix1 | 2-2-1旅行雑費セルの確認 | 確認済み（コード変更なし） |
| Fix2 | 事業名による補助金区分判定の除去 | 完了 |
| Fix3 | 複数選択の単体様式出力を新シート名・グループ化へ統一 | 完了 |

---

## 1. Fix1: 2-2-1旅行雑費セル確認結果

### 確認方法

`書類.xlsx` を openpyxl (data_only=True) で読み込み、SHEET_22（様式２－２－１）のR20C4セル（0-indexed row=19, col=3）の値を hex エンコードで確認。

### 確認結果

```
R20 C4 (0-indexed row=19): hex = e291a220 e69785 e8a18c e99b91 e8b2bb
                            UTF-8 decode = "③ 旅行雑費"
```

**row=19 (0-indexed) = R20 に「③ 旅行雑費」が確定。**

実装済みの `writeSafeNumeric(sheet22, 19, 9, totalTravelMisc)` は正しい。

P3 Take1 の「推定・要目視確認」記載は今回確認完了により解消。コードへのコメントも「確認済み」表記に更新済み。

---

## 2. Fix2: 事業名による補助金区分判定の除去

### 2-a. populate26 タイトル修正

**変更前:**
```java
String title = "選手強化費　　領収書１";
if ("トップチーム".equals(project.getName())) {
    title = "トップチーム選手強化事業　領収書１";
} else if ("ふるさと".equals(project.getName())) {
    title = "ふるさと選手強化事業　領収書１";
}
```

**変更後:**
```java
// タイトル: budgetTypeId ベースで決定（project.getName() による補助金区分判定は使わない）
String title = budgetTypeLabel(project.getBudgetTypeId()) + "　　領収書１";
```

結果: budgetTypeId=1 → "選手強化費　　領収書１" / 2 → "トップチーム活用事業　　領収書１" / 3 → "ふるさと選手活動支援　　領収書１"

### 2-b. populate24Side タイトル修正

**変更前:**
```java
writeSafe(sheet, 1, 0, "令和" + rYear + "年度　国スポ選手強化プロジェクト（①選手強化費）事業実施報告書");
```

**変更後:**
```java
Integer btId = project.getBudgetTypeId();
String budgetPart = (btId != null && btId >= 1 && btId <= 3)
        ? circledNumber(btId) + budgetTypeLabel(btId)
        : budgetTypeLabel(btId);
writeSafe(sheet, 1, 0, "令和" + rYear + "年度　国スポ選手強化プロジェクト（" + budgetPart + "）事業実施報告書");
```

結果: budgetTypeId=1 → "①選手強化費" / 2 → "②トップチーム活用事業" / 3 → "③ふるさと選手活動支援"

### project.getName() 残存確認

```
rg "project\.getName\(\)" ExcelExportService.java
```

残存箇所: **1件** (line 895, `pruneTemplateEllipses24Side` 内)

```java
String keepProject  = (project != null) ? "PROJECT:"  + project.getName() : null;
```

これは帳票テンプレート上の図形（丸印）削除用途（PROJECT:強化練習 / PROJECT:遠征試合 の選択）であり、**補助金区分判定ではない**。差し戻し指示にも「補助金区分判定ではないため残してよい」と明記されているため除去対象外。

---

## 3. Fix3: 複数選択の単体様式出力に新シート名・グループ化を適用

### 3-a. exportForm24 (multi-ID)

**変更前:** 単純に 2 件ずつペアリング（グループ化なし）、シート名 `"2-4_" + id1 + "_" + id2`

**変更後:** `buildCombinedWorkbook` と同じロジックを適用
- `budgetTypeId + targetCategory` でグループ化
- グループ内でのみペアリング
- シート名: `2-4_[補助金区分]_[種別]_[①②③]`（sanitize + uniqueName）

単独出力（1件）のシート名も `"2-4_" + id` → `2-4_[補助金区分]_[種別]_①` に変更。

### 3-b. exportForm25 / exportForm26 (exportMultiSheet)

**変更前:** `exportMultiSheet(SHEET_25, ...)` / `exportMultiSheet(SHEET_26, ...)`
- シート名: `[事業名]_[id]` 形式（事業名ベース）
- 削除判定: `sName.matches(".*_\\d+$")`

**変更後:** `exportMultiSheet("2-5", SHEET_25, ...)` / `exportMultiSheet("2-6", SHEET_26, ...)`
- ソート: budgetTypeId → categoryOrder → eventDate → id
- グループカウンター: `Map<String, Integer>` でグループ内連番
- シート名: `2-5_[補助金区分]_[種別]_[①②③]` / `2-6_...`
- 削除判定: `!sName.startsWith(prefix + "_")`

---

## 4. 変更ファイル一覧

| ファイル | 変更内容 |
|----------|---------|
| `src/main/java/.../service/ExcelExportService.java` | Fix1コメント更新、Fix2 populate26/populate24Side タイトル修正、Fix3 exportForm24/exportMultiSheet 新シート名・グループ化 |
| `src/main/resources/application.properties` | v2.2.0 → v2.2.1 |

---

## 5. コンパイル結果

```
.\mvnw.cmd -q -DskipTests compile
Exit: 0
target/classes/application.properties の app.version=v2.2.1 確認済み
```

---

## 6. 出力経路ごとの仕様統一確認

| 出力経路 | ソート | グループ化 | 新シート名 |
|----------|--------|-----------|------------|
| `exportAllFormsForProjects` (all) | ✓ | ✓ | ✓ |
| `exportYearlySummary` | ✓ | ✓ | ✓ |
| `exportForm24` (単独) | N/A | N/A | ✓ |
| `exportForm24` (複数) | ✓ | ✓ | ✓ |
| `exportForm25` (複数) | ✓ | ✓ (カウンター) | ✓ |
| `exportForm26` (複数) | ✓ | ✓ (カウンター) | ✓ |

---

## 7. Stop Conditions 遵守確認

- `git reset --hard` / `git restore .` / `git clean` の自動実行: **なし**
- 実 Claude 自動起動: **なし**
- DBスキーマ変更: **なし**
- 無関係なリファクタ: **なし**
