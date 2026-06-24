# Cycle 8.3 Dex補強版 P2: UI改善・Excelシート名適正化・決算書旅行雑費修正

## 0. 結論

Air草案 `docs/handoff/P1_Air_Blueprint/cycle_8_3_draft.md` の方向性はOKです。
ただし危険タスクのため、以下のDex補強条件を必ず守って実装してください。

今回の変更は **Excel出力・金額計算・一覧検索・UIを同時に触る危険タスク** です。
無関係なリファクタ、大規模な設計変更、DBスキーマ変更は行わないでください。

## 1. 対象ファイル

主な対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/ProjectMapper.java`
- `src/main/resources/mapper/ProjectMapper.xml`
- `src/main/resources/templates/activity/form.html`
- `src/main/resources/templates/activity/list.html`

必要がある場合のみ:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/model/Project.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/BudgetTypeMapper.java`

ただしDBスキーマ変更は禁止です。

## 2. 最重要注意点

### 2.1 `project.getBudgetType().getName()` は現状そのまま使わない

現行の `Project` モデルには `BudgetType budgetType` フィールドがなく、あるのは `budgetTypeId` です。
したがって、Air草案の `project.getBudgetType().getName()` をそのまま書くとコンパイルエラーになります。

補助金区分名は、以下のどちらかの安全な方法で取得してください。

推奨:

- `ExcelExportService` 内に `budgetTypeLabel(Integer budgetTypeId)` のようなprivate helperを作る。
- `ActivityController#budgetLabel` と同じ対応にする。
  - `1 -> 選手強化費`
  - `2 -> トップチーム活用事業`
  - `3 -> ふるさと選手活動支援`
  - その他/nullは安全な短い文字列にする。

禁止:

- 事業名 `project.getName()` から補助金区分を推測する。
- 存在しない `getBudgetType()` を呼ぶ。
- このためだけにDBスキーマを変える。

## 3. Excelシート名・グループ化

### 3.1 シート名形式

一括出力時の生成シート名を以下に寄せてください。

```text
[様式]_[補助金区分]_[種別]_[連番]
```

例:

```text
2-4_選手強化費_成年男子_①
2-5_選手強化費_成年男子_①
2-6_選手強化費_成年男子_①
```

注意:

- Excelシート名は31文字制限があります。既存の `uniqueName` を拡張するなどして必ず31文字以内にしてください。
- `/ \ ? * [ ] :` などExcelシート名に使えない文字は安全な文字へ置換してください。
- 同名衝突時は既存の `uniqueName` と同様に重複回避してください。

### 3.2 並び順

一括出力時は以下の順で生成してください。

1. 様式2-4 全て
2. 様式2-5 全て
3. 様式2-6 全て

各様式内のソート順:

1. 補助金区分ID昇順
2. 種別順: `成年男子 -> 成年女子 -> 少年男子 -> 少年女子 -> その他`
3. 活動日昇順
4. ID昇順

### 3.3 様式2-4のペアリング

様式2-4で2事業を1シートの左右に結合する場合、同じグループ内だけでペアにしてください。

グループキー:

```text
budgetTypeId + targetCategory
```

ルール:

- グループごとに活動日昇順で並べる。
- 2件ずつペアにする。
- 左側は古い日付、右側は新しい日付。
- グループ内に1件だけ余った場合は左側に出力し、右側は `clearSide24` で空欄化する。
- 単独出力時に、年度内の偶数/奇数位置で左右が変わる既存挙動は今回の不具合原因になりやすいので、単独出力は原則「左側に対象・右側空欄」で固定してください。

## 4. 様式2-2-1 決算書の旅行雑費

現行 `populate22Summary` は旅行雑費を出力していません。
今回の目的は、旧仕様の `expenses.miscellaneous_cost` 合計ではなく、サマリーの新仕様で旅行雑費を集計して決算書へ反映することです。

### 4.1 計算式

プロジェクトごとに以下で計算してください。

```text
旅行雑費 = summary.travelMiscCost × 参加人数 × summary.travelMiscDays
```

参加人数は `participantMapper.findByProjectId(id).size()` または `getLoadedParticipants(id).size()` を使ってください。

### 4.2 出力セル

テンプレートの旅行雑費行に出力してください。
既存コードだけでは旅行雑費の行番号が明確でないため、CCは実装前に `書類.xlsx` の様式2-2-1で旅行雑費行を確認し、コメントで行番号根拠を残してください。

もしテンプレート上の行が確定できない場合は、推測で別行へ出力せず、P3報告で「旅行雑費セル未確定」と明記して止めてください。

### 4.3 禁止

- `Expense#getMiscellaneousCost()` を決算書の旅行雑費集計に使わない。
- 2-6個人別明細の雑費出力仕様を今回ついでに大きく変えない。

## 5. UI / UX改善

### 5.1 宿泊費入力

`form.html` の宿泊費単価と宿泊数は以下の意図を守ってください。

- 表示順は `[単価]円 × [泊数]泊`
- `※単価は1泊分・最大3泊` を表示する。
- 既存の `recalculateAccommodationCosts()` にある「rate===0 かつ宿泊チェックありの場合は保存済み値を維持」は必ず維持する。
- 様式2-6の宿泊費入力欄は `readonly` にして、ユーザーの直接編集ではなく宿泊設定からの自動計算に寄せる。
- `readonly` にしてもフォーム送信値は送られるため、`disabled` にはしない。

### 5.2 旅行雑費UI

旅行雑費は以下の表示にしてください。

```text
[単価]円 × [日数]日 × [人数]人 = [合計]円
```

要件:

- 人数は参加者名簿の有効行数に連動する。
- 参加者の追加・削除・氏名変更時にも合計表示が更新される。
- `summary.travelMiscCost` と `summary.travelMiscDays` のname属性は維持し、保存処理を壊さない。
- 表示用の合計は保存項目を増やさずJS計算でよい。

### 5.3 総合計レイアウト

`tfoot` の総合計は見やすくしてよいですが、既存の `calculateTotals()` が参照しているIDを壊さないでください。

維持するID:

- `totalTransport`
- `totalAccommodation`
- `grandTotal`

## 6. 活動一覧の絞り込み

### 6.1 追加条件

一覧に以下を追加してください。

- 種別 `targetCategory`
- 事業名部分一致 `projectName`

### 6.2 変更対象

`ProjectMapper#findFiltered` の引数を拡張し、XMLも対応させてください。

新条件の例:

```sql
AND target_category = #{targetCategory}
AND name LIKE CONCAT('%', #{projectName}, '%')
```

空文字は条件なしとして扱ってください。

### 6.3 Controller / list.html

`ActivityController#list` と `exportYear` の両方で同じ絞り込み条件を使ってください。

重要:

- 一覧に表示された条件と「年度まとめExcel出力」の対象がズレないようにする。
- `list.html` のExcel出力リンクにも `targetCategory` と `projectName` を引き継ぐ。
- 表示順は `年度 → 月 → 補助金区分 → 種別 → 事業名`。

## 7. 実装順序

以下の順で進めてください。

1. `ProjectMapper.findFiltered` を拡張し、Controller/list/exportYearの絞り込みを整合させる。
2. `ExcelExportService` に補助金区分ラベル・種別順・シート名sanitize helperを追加する。
3. 一括出力のソート・2-4ペアリング・シート名を修正する。
4. 単独2-4出力を左側固定に修正する。
5. 2-2-1旅行雑費を新計算式で出力する。
6. `form.html` の宿泊費readonly・旅行雑費UI・総合計レイアウトを修正する。
7. コンパイルと手動確認観点をP3に記録する。

## 8. 検証

最低限、以下を実行してください。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

可能なら以下も確認してください。

- アプリ起動後、活動一覧の年度・月・補助金区分・種別・事業名検索が組み合わせで動く。
- 一覧の検索条件をかけた状態で年度まとめExcelを出し、対象が一覧と一致する。
- 複数事業のExcel一括出力で、2-4/2-5/2-6の順番とシート名が仕様通り。
- 2-4は同じ補助金区分 + 同じ種別だけで左右ペアになる。
- 単独2-4は左側に対象、右側は空欄。
- 2-2-1の旅行雑費が `単価×人数×日数` で出る。
- 宿泊費単価0入力時に既存宿泊費が0円上書きされない。
- 様式2-6の宿泊費欄がreadonlyだが保存値は送信される。

## 9. P3報告に必ず書くこと

CCは実装完了後、`docs/handoff/P3_CC_Report/cycle_8_3.md` を作成し、以下を記録してください。

- 変更ファイル一覧。
- `Project#getBudgetType()` を使わず、どの方法で補助金区分名を取得したか。
- 2-2-1旅行雑費の出力セル・行番号根拠。
- `mvnw compile` の結果。
- 未確認事項があれば正直に記載。

