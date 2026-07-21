[C12B: Dex(P2) => CC(P3)]

# Cycle 12B 予算管理・様式2-3連動 事前監査 / CC向け実装指示書

## 判定

**条件付きOK。CCは12AのP4 OK後に、12Bのみ実装してください。**

Air(P1)の `docs/handoff/P1_Air_Blueprint/cycle_12b_12c_planning.md` は、Kazumaxの運用方針を反映しており、12Bの方向性は妥当です。

ただし、12AがまだCC実装中のため、12Bの実装開始条件を次のように固定します。

- 12Aの実装が完了していること。
- 12AのP3報告書が出ていること。
- Dex(P4)が12AをOKにしていること。
- 12Aの変更が作業ツリー上で混ざっていないこと。

この条件を満たすまでは、12Bのコード・DB・テンプレート・HTMLを変更しないでください。

---

## 今回やること / やらないこと

### やること: Cycle 12B

- `budget_allocations` テーブル追加
- 予算管理画面追加
- 既存事業から、年度・補助金区分・対象区分の入力行を自動表示
- 内示額の一括保存
- 年度末出力に `様式２－３` を含める
- 様式2-3下部の「内示額」「移動後の総額」を出力

### やらないこと: Cycle 12C

- 大容量プレビューのタブ化
- モーダル式の出力前確認画面
- `/api/export/preview-yearly`
- JavaScript中心のプレビューUI刷新

---

## CCが最初に読むファイル

- `docs/handoff/P1_Air_Blueprint/cycle_12b_12c_planning.md`
- `docs/handoff/P2_Dex_to_CC/cycle_12_original_formula_audit.md`
- `docs/handoff/P2_Dex_to_CC/cycle_12_annual_export_take2_final_instructions.md`
- このファイル
- `docs/PROJECT_RULES.md`

このファイルが12Bの最終指示です。Air草案と矛盾する場合は、このファイルを優先してください。

---

## 0. 12Bの設計強化ポイント

12BはDB・画面・Excel出力が同時に関わるため、CCは以下の考え方で実装してください。

- **DBは内示額だけを保存する。** 決算額は保存せず、既存事業データから都度集計する。
- **予算管理画面は入力専用。** Excel出力や集計値の修正画面にしない。
- **様式2-3は下部表だけを自動出力する。** 上部の変更理由・移動額欄は手入力運用のままにする。
- **12Aの集計ロジックを二重化しない。** 2-2-1と2-3の決算額は同じ集計ヘルパーから作る。
- **トップチームの2-3行は推測で作らない。** 原本に非例示行がない限り自動書込しない。

中学生向けに言うと、12Bは「予算のメモ帳」と「2-3に数字を写す係」です。
会計の計算ルールそのものを作り替える作業ではありません。

---

## 1. DB設計

`src/main/resources/schema.sql` に、毎回起動しても安全な形で以下を追加してください。

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

注意:

- `DROP` は禁止。
- 既存データを消す処理は禁止。
- 金額はJava側で `long` / DB側で `BIGINT` を使う。
- `allocated_amount` は負数禁止。画面とサーバー側の両方で0以上に制限する。
- `schema.sql` は `spring.sql.init.mode=always` で毎回実行されるため、`CREATE TABLE IF NOT EXISTS` と `INSERT/UPDATE` 以外の危険なDDLを増やさない。
- もし開発途中でテーブル定義を修正する必要が出た場合、CC判断で破壊的変更をせず、P3に「定義変更が必要」と書いてDexへ戻してください。

---

## 2. Model / Mapper

以下を追加してください。

- `BudgetAllocation` model
- `BudgetAllocationMapper.java`
- `mapper/BudgetAllocationMapper.xml`

必要な操作:

- 年度別に登録済み内示額を取得
- 年度・補助金区分・対象区分で1件取得
- `INSERT ... ON DUPLICATE KEY UPDATE` によるupsert
- 既存事業から年度内の入力対象行を取得

推奨メソッド:

- `findByFiscalYear(int fiscalYear)`
- `findOne(int fiscalYear, int budgetTypeId, String targetCategory)`
- `upsert(BudgetAllocation allocation)`
- `findRequiredRowsFromProjects(int fiscalYear)`

入力対象行は、`projects` から以下の単位で作ります。

- `fiscal_year`
- `budget_type_id`
- `target_category`

対象は「その年度に実績として登録済みのカテゴリだけ」です。
Kazumax合意済みのB案です。

注意:

- `target_category` が空またはnullの事業は、予算管理の入力対象に出さない。
- `budget_type_id` がnullの事業は、予算管理の入力対象に出さない。
- 表示順は `budget_type_id` 昇順、対象区分は `成年男子 → 成年女子 → 少年男子 → 少年女子 → その他` を推奨する。
- DBから戻した `allocated_amount` がnullにならないよう、Java側でも0補正する。

---

## 3. 予算管理画面

### URL

- `GET /budget-allocations?year=2025`
- `POST /budget-allocations/save`

Controller名は既存命名に合わせて `BudgetAllocationController` などでよいです。

### ナビゲーション

`src/main/resources/templates/layout.html` の上部ナビに「予算管理」を追加してください。

### 画面仕様

テンプレート例:

- `src/main/resources/templates/budget_allocations/index.html`

表示内容:

- 年度選択
- その年度に登録済みの `budget_type_id + target_category` 行
- 補助金区分名
- 対象区分
- 内示額入力欄
- 一括保存ボタン

初期表示:

- 年度未指定なら現在年度。
- 既存の事業がない年度では、空状態メッセージを表示。

保存:

- 表示された行だけ保存する。
- 入力なしは0として扱う。
- 負数は保存しない。
- 保存後は同じ年度の画面に戻る。
- 保存成功時は短い成功メッセージを表示する。
- 不正入力があった場合は、保存せず同じ画面で分かるメッセージを表示する。
- 画面上の金額入力欄は `type="number"`、`min="0"`、`step="1"` を使う。
- カンマ付き入力を許可する場合は、サーバー側でカンマ除去してから数値化する。難しければカンマ入力は許可しない。

---

## 4. 様式2-3 出力仕様

Kazumax合意により、**上部の「変更理由・移動額」欄は自動計算しません。**

CCが出力するのは、下部の「補助額変更後」表の以下だけです。

- `K列`: 内示額
- `T列`: 移動後の総額、つまり決算額
- `AC列`: 総額（合計）。基本的にはT列と同じ値を入れる

原本確認済みの主な行:

| 区分 | 原本行 | 備考 |
|---|---:|---|
| 選手強化 / 成年男子 | 25 | 実データ行 |
| 選手強化 / 成年女子 | 26 | 実データ行 |
| 選手強化 / 少年男子 | 27 | 実データ行 |
| 選手強化 / 少年女子 | 28 | 実データ行 |
| トップチーム | 30-31 | 原本では `例）` 行。自動書込対象にしない |
| ふるさと / 成年男子 | 33 | 実データ行 |

### 動的行検索ルール

Air草案の「B列を検索」は採用してよいですが、完全一致は禁止です。
原本のB列にはふりがな等が混ざっています。

検索時は、B列文字列を正規化してください。

- 空白を除去
- 全角/半角差をなるべく吸収
- `例）` または `例)` で始まる行は書き込み対象外
- 対象区分名を含む行を候補にする
- ただし、補助金区分のセクション範囲を守る

セクション範囲:

- 選手強化: 25〜28行
- トップチーム: 30〜31行。ただし現原本では例行なので原則スキップ
- ふるさと: 33行

トップチームの内示額・決算額を様式2-3へ書く場合は、正式な非例示行が原本に存在することを確認してからにしてください。
非例示行がない場合は、トップチーム分は様式2-3へ自動書込せず、P3報告書に「原本に非例示行なし」と明記してください。

### 書き込みセルの固定ルール

行が決まったら、列は以下に固定してください。

- 内示額: `K`
- 決算額: `T`
- 総額: `AC`

その他の列には書き込まないでください。
特に `L:S` や `AM:AO` 付近には原本由来の式や補助欄があるため、12Bでは触らないでください。

---

## 5. 決算額の集計ルール

様式2-3のT列/AC列へ入れる決算額は、12Aで作った2-2-1集計と同じロジックにしてください。

基本:

- 交通費: 参加者ごとの `Expense.transportCost` 合計
- 宿泊費: 参加者ごとの `Expense.accommodationCost` 合計
- 旅行雑費: `ProjectSummaryExpense.travelMiscCost * 参加者数 * ProjectSummaryExpense.travelMiscDays`
- 駐車料金: `ProjectSummaryExpense.parkingCost`
- 借用料: `ProjectSummaryExpense.rentalCost`
- 報償費: `ProjectSummaryExpense.compensationCost`
- 需用費: `ProjectSummaryExpense.suppliesCost`
- 役務費: `ProjectSummaryExpense.serviceCost`

補助金区分ごとの対象費目は、12Aの指示書に合わせてください。
未対応費目を黙って捨てないでください。

集計単位:

- `fiscal_year`
- `budget_type_id`
- `target_category`

### 集計ヘルパー契約

CCは、可能であれば `ExcelExportService` 内に以下のような内部用データ構造または同等のヘルパーを作ってください。

- `budgetTypeId`
- `targetCategory`
- `transport`
- `accommodation`
- `travelMisc`
- `parking`
- `rental`
- `compensation`
- `supplies`
- `service`
- `excluded`
- `total`

この集計結果を、2-2-1と2-3の両方から参照できる形にしてください。
同じ金額を別々の場所で再計算すると、後でズレやすくなります。

---

## 6. ExcelExportServiceへの追加

12Aの `exportYearlySummary(...)` を拡張し、年度末ブックに `様式２－３` を含めてください。

必須:

- 12Aで保持した `様式２－１`、`様式２－２`、2-2-1各種、2-4/2-5/2-6を壊さない。
- `様式２－３` は12Bで追加する。
- 上部の移動額欄は空欄または原本値クリア。自動計算しない。
- K/T/AC列に書き込むセルだけを明示的に処理する。
- `workbook.setForceFormulaRecalculation(true)` を維持する。

可能なら、2-2-1用の集計処理と2-3用の集計処理を同じヘルパーに寄せ、同じ入力から同じ決算額になるようにしてください。

### 12Aとの衝突防止

12Bの着手時に、CCは必ず12Aの最終状態を確認してください。

- 12AのP4 OKファイルを読む。
- 12Aで確定した `exportYearlySummary(...)` の仕様を壊さない。
- 12Aで追加された提出日・団体名・代表者情報の引数や処理がある場合、それを維持する。
- 12Bでは、様式2-3追加に必要な最小差分だけを入れる。

---

## 7. バージョン

12Aが `v2.4.0` の場合、12Bは `v2.4.1` にしてください。

ただし、12Aの最終P4結果で別バージョンになっている場合は、そこから1つ上げてください。

---

## 8. 検証条件

CCは最低限、以下を検証してP3報告書に書いてください。

### コマンド

1. `.\mvnw.cmd -q -DskipTests compile`
2. `target/classes/application.properties` の `app.version` が更新後バージョンと一致

### DB

- `budget_allocations` が起動時に作成される
- 再起動しても既存データが消えない
- 同じ年度・補助金区分・対象区分を保存しても重複せず更新される
- 負数が保存されない

### 画面

- ナビから予算管理へ移動できる
- 年度選択ができる
- 登録済み事業のあるカテゴリだけ表示される
- 内示額を保存して再表示できる
- 事業がない年度で空状態が表示される

### Excel

- 年度末出力に `様式２－３` が含まれる
- `K列` に内示額が入る
- `T列` と `AC列` に決算額が入る
- 上部の「変更理由・移動額」欄を自動計算していない
- 選手強化の4カテゴリで行ズレがない
- ふるさと成年男子で行ズレがない
- トップチームは、原本に非例示行がない場合は自動書込しない
- 12Aの2-1/2-2/2-2-1/2-4/2-5/2-6出力が壊れていない
- 予算管理画面で保存した内示額と、出力ExcelのK列が一致する
- 2-2-1の各区分支出合計と、様式2-3のT/AC列の決算額が一致する
- 同じ年度で再出力しても結果が変わらない
- 内示額が0円でも出力が壊れない
- 該当カテゴリの事業が0件の場合、様式2-3へ推測値を書き込まない

---

## 9. P3報告書

保存先:

`docs/handoff/P3_CC_to_Dex/cycle_12b_budget_allocations_form23.md`

P3には以下を必ず含めてください。

- 12A P4 OK後に着手したこと
- 変更ファイル一覧
- DBスキーマ追加内容
- 追加したURLと画面
- 予算管理の保存・再表示確認
- 様式2-3へ書き込んだセル一覧
- トップチーム行の扱い
- 検証コマンド結果
- `app.version` のsrc/target同期確認
- 未対応範囲として12Cを残したこと

---

## Dexメモ

Air草案の方向性はOKです。
ただしDex判断で以下を固定しました。

- 12Bは12AのP4 OK後に開始。
- 12Cは今回対象外。
- 2-3上部の移動額欄は自動計算しない。
- B列検索は完全一致禁止。ふりがな混在と例示行を考慮する。
- トップチームは原本に非例示行がないため、推測で例示行に書かない。
- 金額は `long` / `BIGINT`。

CCはこの範囲で実装し、P3をDexへ戻してください。
