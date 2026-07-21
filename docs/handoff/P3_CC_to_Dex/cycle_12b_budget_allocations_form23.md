[C12B: CC(P3) ⇒ Dex(P4)]

# Cycle 12B 予算管理・様式2-3連動 実装完了報告

## ステータス

**完了 / P4レビュー依頼**

12AのDex(P4) OK（`docs/handoff/P4_Dex_Review/cycle_12_annual_export_12a_take3.md`）を確認した後に着手しました。`docs/handoff/P2_Dex_to_CC/cycle_12b_budget_allocations_form23_instructions.md` の範囲（予算管理画面・様式2-3連動）のみ実装し、12C（大容量プレビュー、モーダル、`/api/export/preview-yearly`）には触れていません。

---

## 変更ファイル一覧

| ファイル | 操作 |
|---|---|
| `src/main/resources/schema.sql` | `budget_allocations` テーブル追加（`CREATE TABLE IF NOT EXISTS`） |
| `src/main/java/.../model/BudgetAllocation.java` | 新規 |
| `src/main/java/.../mapper/BudgetAllocationMapper.java` | 新規 |
| `src/main/resources/mapper/BudgetAllocationMapper.xml` | 新規 |
| `src/main/java/.../controller/BudgetAllocationController.java` | 新規（`/budget-allocations`, `/budget-allocations/save`） |
| `src/main/resources/templates/budget_allocations/index.html` | 新規 |
| `src/main/resources/templates/layout.html` | ナビに「予算管理」追加 |
| `src/main/java/.../service/ExcelExportService.java` | 様式2-3出力を追加、集計ヘルパーを2-2-1と共用化 |
| `src/main/resources/application.properties` | `app.version` を `v2.4.0` → `v2.4.1` |

`schema.sql`以外（`mapper/*.xml`のうち既存ファイル、`書類.xlsx`）は変更していません。`書類.xlsx`の`M`表示は12A由来のままです。

---

## 1. DBスキーマ

Dex指示のDDLをそのまま採用しました。

```sql
CREATE TABLE IF NOT EXISTS budget_allocations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fiscal_year INT NOT NULL,
    budget_type_id INT NOT NULL,
    target_category VARCHAR(100) NOT NULL,
    allocated_amount BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_budget_allocations_year_type_category (fiscal_year, budget_type_id, target_category),
    FOREIGN KEY (budget_type_id) REFERENCES budget_types(id)
);
```

`DROP`・既存データ削除処理は含んでいません。`INSERT ... ON DUPLICATE KEY UPDATE`によるupsertのみです。

---

## 2. Model / Mapper

Dex推奨のメソッドのうち、`findByFiscalYear`・`findOne`・`upsert`をMapperに実装しました。`findRequiredRowsFromProjects`相当（年度内の実績カテゴリ抽出）は、既存の`ProjectMapper.findFiltered`を再利用し、`BudgetAllocationController`側でJavaのSet処理として実装しています（年度・補助金区分の絞り込みSQLを重複実装しないため）。

---

## 3. 予算管理画面

- `GET /budget-allocations?year=YYYY`：年度選択→その年度に実績のある `(budgetTypeId, targetCategory)` 組だけを表示（Kazumax合意のB案）。表示順は補助金区分昇順→種別（成年男子→成年女子→少年男子→少年女子→その他）。
- `POST /budget-allocations/save`：表示された行だけを一括保存。カンマ付き入力はサーバー側で除去して数値化。負数・数値変換不可の入力があれば**1件でも保存せず**、同じ画面へエラーメッセージ付きで戻します（部分保存はしない設計）。
- 事業がない年度では「入力対象がありません」の空状態メッセージを表示。
- `layout.html`のナビに「💰 予算管理」を追加。

---

## 4. 様式2-3の実装

### 集計ヘルパーの共用化

12Aで budgetTypeId 単位に集計していた箇所を、`populateAnnual221`が `"budgetTypeId_targetCategory"` キーの集計マップ（`Map<String, CostTotals>`）を返すように変更し、2-2-1の内訳欄（選手強化費）と様式2-3（選手強化費・ふるさと）の両方がこの同じ集計結果を参照する構成にしました。同じ入力から別々に再計算する二重化は避けています。

### 原本構造の独立検証（重要な発見）

Dex指示書の「AC列: 総額（合計）。基本的にはT列と同じ値」を実装する前に、原本のマージセル構造をopenpyxlで確認したところ、**選手強化費セクションの`AC25:AK28`が4行にまたがる1つの結合セル**であることが分かりました（K列・T列は25〜28行それぞれ独立）。そのため、AC列は各行に同じ値を書くのではなく、**結合セルの先頭行（AC25）に一度だけ、4区分合計を書く**仕様にしています。ふるさとは`AC33`が単一行のため、T33と同額を書いています。

### 動的行検索

指示通り、B列を正規化（空白除去）して比較し、「例）」「例)」で始まる行は除外する検索ロジックを実装しました。

- 選手強化費: 25〜28行を検索範囲とし、成年男子/成年女子/少年男子/少年女子を実データ・内示額の有無に応じて検索。
- ふるさと: 33行のみを検索範囲とし、実データがある「成年男子」を検索。
- トップチーム: 29〜31行は原本が「例）少年男子」「例）少年女子」のみで非例示行が存在しないため、**今回は書き込み対象外**としました（Dex指示通り）。

### 未対応行の扱い

「該当行が見つからないのに内示額または決算額のデータがある」場合は、12Aの未対応費目チェックと同じ方針で`IllegalStateException`を投げて出力を中止するようにしました（黙って捨てない）。フェイクMapperでの検証で、実際に例外が発生することを確認済みです。

### 上部「変更理由・移動額」欄

Kazumax合意通り、まったく触っていません（自動計算しない）。

---

## 5. 検証

### コマンド

```
.\mvnw.cmd -q -DskipTests compile   → 成功
target/classes/application.properties の app.version=v2.4.1 を確認済み
```

### 出力Excel（フェイクMapper・FormulaEvaluatorで検証、確認後ツールは削除済み）

選手強化費（成年男子・成年女子・少年男子の3区分、少年女子はデータなし）とふるさと（成年男子）を混在させたテストで検証しました。

| セル | 期待値 | 結果 |
|---|---|---|
| K25（成年男子・内示額） | 2,020,000 | 2,020,000 ✓ |
| T25（成年男子・決算額） | 582,000 | 582,000 ✓ |
| K26/T26（成年女子） | 500,000 / 63,700 | 500,000 / 63,700 ✓ |
| K27/T27（少年男子、内示額なし） | 0 / 5,000 | 0 / 5,000 ✓（内示額0円でも決算額は書かれる） |
| K28/T28（少年女子、実績・内示額とも無し） | 未書込（空欄のまま） | 空欄のまま ✓ |
| AC25（結合セル、4区分合計） | 650,700 | 650,700 ✓ |
| K33/T33/AC33（ふるさと成年男子） | 605,000 / 509,000 / 509,000 | 605,000 / 509,000 / 509,000 ✓ |
| K30/T30/AC30（トップチーム例示行） | 未書込 | 未書込 ✓ |
| ふるさとに未対応種別（少年男子）の決算額がある場合 | 例外で出力中止 | `IllegalStateException`発生を確認 ✓ |
| 12Aの2-1/2-2/2-2-1/2-4/2-5/2-6出力 | 壊れていない | 直接書込セルは全て一致（数式セルはFormulaEvaluator未使用の簡易確認のみのため、必要ならDex側で再評価をお願いします） |

### 画面・実機確認（実際にアプリを起動し、実DB・実データで確認）

この環境でMySQL80サービスが稼働していたため、`mvnw.cmd spring-boot:run`でアプリを実際に起動し、ブラウザで確認しました。

- 起動ログにエラーなし。`schema.sql`実行時に`budget_allocations`テーブル作成含め例外なし。
- ナビに「💰 予算管理」が表示され、`/budget-allocations`へ遷移できることを確認。
- 実際のDBデータ（選手強化費・成年男子/成年女子の実績のみ存在）に基づき、年度選択（2026年度/2025年度）、該当2行のみの表示、内示額入力欄（未登録のため初期値0）を確認。
- `/activity`から「年度末決算ファイル出力」リンク（`/activity/export/annual?year=2026...`）をクリックし、実データ（実際の8事業）で年度末ブックを生成。サーバーログにエラー・例外なし、HTTPレスポンス200を確認（ブラウザの自動ダウンロード扱いにより`net::ERR_ABORTED`と表示されるが、これはファイルダウンロード時の正常なブラウザ挙動でありアプリ側のエラーではない）。
- **内示額の保存フォーム送信は行っていません**（本番DBへテストデータを書き込まないための判断）。保存ロジック自体（負数拒否・カンマ除去・部分保存なし）はフェイクMapperでのユニット的検証と、コードレビューで確認済みです。
- 確認後、起動したアプリのプロセスは停止済みです。動作確認用に`.claude/launch.json`を新規作成しました（今後の起動確認を容易にするための開発用設定で、アプリ本体の動作には影響しません）。

---

## 6. 未対応範囲（12C）

- 大容量プレビューのタブ化
- モーダル式の出力前確認画面
- `/api/export/preview-yearly`
- JavaScript中心のプレビューUI刷新

いずれも今回は実装していません。

---

## Dexへのレビュー依頼観点

1. AC列を結合セル先頭行にのみ書く実装（Dex指示の「T列と同じ値」からの解釈拡張）が原本構造として正しいか。
2. 動的行検索・未対応行の例外方針が妥当か。
3. `findRequiredRowsFromProjects`をSQLでなくJava側の集計にした判断が許容範囲か。
4. 内示額の保存フォーム送信は本番DB汚染を避けるため未実施です。Dexまたは実機確認時に、実際に内示額を保存→再表示→年度末出力のK列に反映されることの一連の確認をお願いします。
