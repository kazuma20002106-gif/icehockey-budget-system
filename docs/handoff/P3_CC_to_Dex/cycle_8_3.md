# Cycle 8.3 & 8.4 実装完了報告書 (P3: CC → Dex)

**バージョン**: v2.3.0  
**コミット**: 73165b4  
**日時**: 2026-06-29

---

## ✅ 実装結果サマリー

| タスク | 指示 | 状態 | 備考 |
|--------|------|------|------|
| 1. budgetTypeLabel修正 | null→"未設定", default→"その他" | ✅ 実装済 | ExcelExportService.java |
| 2. シート名31文字制限 | uniqueName 28→31文字 | ✅ 実装済 | ExcelExportService.java |
| 3. 一括出力ソート順 | budgetTypeId→種別→日付→id | ✅ 既存実装を確認・維持 | 既に正しく実装済み |
| 4. 2-4ペアリング | グループキー budgetTypeId+category | ✅ 既存実装を確認・維持 | 既に正しく実装済み |
| 5. 2-2-1旅行雑費セル | J20（row=19,col=9）・新計算式 | ✅ 既存実装を確認・維持 | 既に正しく実装済み |
| 6. UI/UX改善 | 検索フィールド順・宿泊防止 | ✅ 実装済 | list.html 順序変更 |
| 7. UIコンパクト化 | CSS/form.html/list.html/members | ✅ 実装済 | 全対象ファイル対応 |

---

## 📝 変更ファイル詳細

### ExcelExportService.java
- `budgetTypeLabel(null)`: `"不明"` → `"未設定"`
- `budgetTypeLabel(default)`: `"区分" + id` → `"その他"`
- `uniqueName()`: シート名上限 `28` → `31` 文字に修正

### activity/list.html
- 検索フィールド順序を変更：`年度 → 月 → 補助金区分 → 種別 → 事業名`（旧: 年度→補助金区分→月→種別→事業名）
- 絞り込みカード: `p-3` → `p-2`
- 各 `form-select` → `form-select form-select-sm` に変更
- 事業名入力: `form-select` → `form-control form-control-sm` に修正
- 絞り込みボタン: `btn-outline-secondary` → `btn-sm btn-outline-secondary`

### static/css/style.css
- `.table tbody td`: `padding: 12px` → `padding: 6px 8px`
- `.form-control, .form-select`: `padding: 10px 15px` → `padding: 6px 10px`
- `.btn`: `padding: 8px 16px` → `padding: 6px 12px`
- `.main-content`: `padding: 30px` → `padding: 16px 24px`

### activity/form.html
- 全カードの `mb-4` → `mb-3`
- 基本情報、施設経費、日程・成果の `card-body` に `p-2` 追加
- 個人別支出 `card-body`: `p-2` 追加、交通費単価input: `form-control-sm` 追加

### members/index.html
- 新規追加フォーム: `g-3` → `g-2`
- `mb-4` → `mb-3`
- 全入力: `form-control` → `form-control-sm`、`form-select` → `form-select-sm`
- 追加ボタン: `btn` → `btn-sm btn-primary`
- `card-body` に `p-2` 追加

---

## 🔍 タスク3〜5の既存実装確認記録

### タスク3（ソート順）— 既存で正確に実装済み
`buildCombinedWorkbook` および `exportForm24`/`exportMultiSheet` 内:
```java
allProjects.sort(Comparator
    .comparingInt((Project p) -> p.getBudgetTypeId() == null ? 99 : p.getBudgetTypeId())
    .thenComparingInt((Project p) -> categoryOrder(p.getTargetCategory()))
    .thenComparing((Project p) -> p.getEventDate() == null ? LocalDate.of(9999,12,31) : p.getEventDate())
    .thenComparingInt((Project p) -> p.getId() == null ? Integer.MAX_VALUE : p.getId()));
```
`categoryOrder()`: 成年男子=1, 成年女子=2, 少年男子=3, 少年女子=4 ✓

### タスク4（2-4ペアリング）— 既存で正確に実装済み
- グループキー: `budgetTypeId + "_" + targetCategory` ✓
- 左が対象、右が空欄 → `clearSide24(newSheet, 17)` で空欄化 ✓
- グループ内連番: `sheetNum` でカウント ✓
- 単独出力も左=対象、右=空欄 ✓

### タスク5（2-2-1旅行雑費）— セル座標確認・既存実装済み
**Python(openpyxl)による書類.xlsx実読確認:**
- ラベル `"③ 旅行雑費"` → D20 (row=20, col=4)
- 出力先 → **J20 (row=19, col=9 ※0-indexed)**
- 既存コード: `writeSafeNumeric(sheet22, 19, 9, totalTravelMisc)` ✓

**計算式:**
```java
totalTravelMisc += nz(sum.getTravelMiscCost()) * parts.size() * nz(sum.getTravelMiscDays());
```
`Expense#getMiscellaneousCost()` は2-2-1に使用していない ✓

---

## ⚠️ 既存コードで未変更の部分（意図的）

- `populate26()` 内の `getMiscellaneousCost()` 使用: 2-6（個人別領収書）の雑費欄用であり、2-2-1とは別。指示通り触らず維持。
- DB変更: なし（指示通り厳守）
- 2-4/2-5/2-6の出力ロジック本体: 変更なし

---

## 💡 ＋αの提案（詳細は `docs/proposals/CC_cycle_8_3.md` を参照）
