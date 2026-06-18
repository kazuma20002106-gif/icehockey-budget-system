# CC 実装完了報告書 — Cycle 8-2

**バージョン**: v2.0.0  
**日付**: 2026-06-19

---

## 実装タスク一覧

### ✅ DB追加（schema.sql）
- `projects` テーブルに `accommodation_nights INT DEFAULT 0` を追加（`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`）
- `project_summary_expenses` テーブルに `travel_misc_cost INT DEFAULT 0`、`travel_misc_days INT DEFAULT 0` を追加

### ✅ Model追加
- `Project.java`: `accommodationNights` フィールド、getter/setter追加
- `ProjectSummaryExpense.java`: `travelMiscCost`、`travelMiscDays` フィールド、getter/setter追加

### ✅ MyBatisマッパー更新
- `ProjectMapper.xml`: INSERT / UPDATE 両方に `accommodation_nights` / `#{accommodationNights}` 追加
- `ProjectSummaryExpenseMapper.xml`: INSERT / UPDATE 両方に `travel_misc_cost, travel_misc_days` 追加

### ✅ UI改修（activity/form.html）
1. **宿泊数（泊）** フィールドを基本情報セクションに追加（`oninput="recalculateAccommodationCosts()"`）
2. **宿泊費単価（円/泊）** フィールドを個人別支出ヘッダーに追加（交通費単価の隣）
3. **旅行雑費 単価（円/人/日）** と **旅行雑費 日数（日）** フィールドを施設・その他経費セクションに追加
4. **スピナー上方表示修正**: `openDigitSpinner` / `openDistanceSpinner` を `r.bottom` → `r.top - spinnerHeight - 4` に変更
5. **SweetAlert2による削除確認**: `removeRow()` に `Swal.fire()` 確認ダイアログ追加
6. **名簿サジェスト最適化**: `updateMemberList()` 関数追加（入力済み氏名を datalist から除外）、`mirrorName()` から呼び出し
7. **宿泊費自動計算**: `recalculateAccommodationCosts()` 関数追加（宿泊単価×泊数を宿泊チェック参加者に自動入力）、`toggleAccom()` からも呼び出し
8. **離脱警告**: `formDirty` フラグ + `beforeunload` リスナー追加

### ✅ 他HTMLファイル
- `activity/list.html`: 新規入力ボタンを `btn-lg` に拡大、`＋ 新規入力` テキストに変更
- `export/index.html`: 全選択チェックボックスに `<label for="selectAll">全選択</label>` 追加、`checkboxes = ` を `const checkboxes =` に修正
- `members/index.html`: `deleteMember()` の `confirm()` を `Swal.fire()` に置き換え

### ✅ ExcelExportService.java（様式2-4 / 2-5 / 2-6）

**【至急バグ修正】様式2-6 交通区間文字化け修正**:
- `writeMergedTransportText()` 内の `Font font = wb.createFont()` ブロック（3行）を削除
- 旧コードは日本語フォントを新規の空フォントで上書きしていた → 修正により既存テンプレートのフォント設定を維持

**様式2-4 旅行雑費計算修正**:
- `miscSum`（個人別 miscellaneousCost の合計）を廃止
- `travelMiscTotal = travelMiscCost × (coachCount + playerCount) × travelMiscDays` に変更
- 右側（colOffset=17）専用セルへの書き込み追加：
  - row 22, col 17: `travelMiscDaysVal`（日数）
  - row 22, col 25: `travelMiscCostVal`（単価）
  - row 22, col 30: `coachCount + playerCount`（人数）
  - row 22, col 34: `travelMiscDaysVal`（日数・計算式用）

**様式2-5 宿泊日数対応**:
- 日程表記: `plusDays(1)` → `plusDays(accommodationNights)` に変更
- 宿泊ヘッダー: col 7固定 → `col 7+n`（n = 0〜nightCols-1、最大3列）にループ変更
- 参加者〇印: col 7固定 → 各泊の列にループ書き込み、未使用列はクリア

---

## 【前提確認状況】

### 様式2-4
- 右側計算セル（row 22, cols 17/25/30/34）: `clearSide24(colOffset=17)` のクリア対象として既存コードに明記されていたため確認済み

### 様式2-5
- 宿泊ヘッダー列（col 7以降）の結合状態: P2指示書に記載なし。`writeSafe()` で書き込みのみ（結合変更なし）のため既存フォーマットを破壊するリスクは低いが、Dexによる目視確認を推奨

### 様式2-6
- `writeMergedTransportText()` の結合範囲: `FORM26_TRANSPORT_COL_START`〜`FORM26_TRANSPORT_COL_END`（N:S / col 13-18）× 3行。変更前後とも同じ結合範囲。フォント削除のみ変更。

---

## ファイル変更一覧

| ファイル | 変更種別 |
|---|---|
| `src/main/resources/schema.sql` | 修正（ALTER TABLE 3件追加） |
| `src/main/java/.../model/Project.java` | 修正（accommodationNights追加） |
| `src/main/java/.../model/ProjectSummaryExpense.java` | 修正（travelMiscCost/Days追加） |
| `src/main/resources/mapper/ProjectMapper.xml` | 修正（INSERT/UPDATE更新） |
| `src/main/resources/mapper/ProjectSummaryExpenseMapper.xml` | 修正（INSERT/UPDATE更新） |
| `src/main/java/.../service/ExcelExportService.java` | 修正（フォントバグ修正・2-4/2-5計算更新） |
| `src/main/resources/templates/activity/form.html` | 修正（UI/UX改善8項目） |
| `src/main/resources/templates/activity/list.html` | 修正（新規入力ボタン拡大） |
| `src/main/resources/templates/export/index.html` | 修正（全選択ラベル追加・const修正） |
| `src/main/resources/templates/members/index.html` | 修正（SweetAlert削除確認） |
| `src/main/resources/application.properties` | 修正（v1.9.9 → v2.0.0） |

---

## セルフ QA チェック

- [x] `git diff` で意図しない巻き添え変更なし（上記ファイル以外の src/ 変更なし）
- [x] `.\mvnw compile` → BUILD SUCCESS（警告なし）
- [x] `target/classes/application.properties` の `app.version=v2.0.0` を確認
- [x] Font import削除（未使用）済み
- [x] miscSum の用途がなくなったため変数ごと削除済み

---

## Dexへの確認依頼

1. **2-6 交通区間**: 日本語フォント（MS Gothic等）が正しく表示されているか目視確認をお願いしたい
2. **2-4 旅行雑費**: 右側セル（R23C18, R23C26, R23C31, R23C35）に値が書き込まれているか確認
3. **2-5 宿泊ヘッダー**: 宿泊日数が2以上の場合、col 8に翌日の日付が表示されるか確認
4. **form.html スピナー**: スピナーが入力欄の「上」に表示されるか確認
5. **form.html 離脱警告**: フォーム入力後にページ離脱しようとした際にブラウザ警告が出るか確認
