[Air(P1) ⇒ Dex(P2) / CC(P3)]

# Cycle 18 Blueprint: schema.sql の MySQL互換性（ALTER構文）修正

Cycle 17で判明した「過去の `ADD COLUMN IF NOT EXISTS` がMySQL 8でサイレントエラーになっていた件」への対応方針（Blueprint）です。

---

## 1. 優先度と必須判定
*   **優先度: 【最高（Blocker）】**
*   **VPS本番構築前に必須か？**: **YES。絶対に対応が必要です。**
    *   **理由**: Kazumax様のローカル環境では、過去に手動などで列が追加されていたため「エラーを吐きつつも起動する」状態でした。しかし、VPS（まっさらなLinuxサーバー）に移行してゼロからMySQLデータベースを作った際、これらの列が作られず、**初回起動時にアプリが100%クラッシュ（即死）します。** フェーズ2へ進む前に必ず直さなければなりません。

## 2. 修正範囲の点検結果
*   `schema.sql` 全体を検索・点検した結果、非互換の `ADD COLUMN IF NOT EXISTS` が使われているのは、**CCが報告した以下の3列のみ**でした。
    1.  `projects.accommodation_nights`
    2.  `project_summary_expenses.travel_misc_cost`
    3.  `project_summary_expenses.travel_misc_days`
*   よって、修正範囲はこの3列の安全化のみで完了します。（※Cycle 17で追加された `is_printed` はすでに安全な書き方になっています）。

## 3. 実装方針（安全な冪等SQLの記述）
*   MySQL 8で安全に何度でも実行できる（冪等性を保つ）ために、Cycle 17の `is_printed` 列追加で確立した**「INFORMATION_SCHEMAによる存在確認 ＋ PREPARE構文による動的SQL」**のパターンを上記3列にも適用します。

**【実装イメージ（CC向け）】**
```sql
-- accommodation_nights の例
SET @acc_nights_exists = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects' AND COLUMN_NAME = 'accommodation_nights'
);
SET @add_acc_nights_sql = IF(@acc_nights_exists = 0,
    'ALTER TABLE projects ADD COLUMN accommodation_nights INT DEFAULT 0',
    'SELECT 1');
PREPARE add_acc_nights_stmt FROM @add_acc_nights_sql;
EXECUTE add_acc_nights_stmt;
DEALLOCATE PREPARE add_acc_nights_stmt;
```
※上記を残りの2列にも適用し、元の `ALTER TABLE ... IF NOT EXISTS` 構文を削除します。

## 4. 既存データへの影響と安全性
*   **既存データは絶対に壊れません。** `INFORMATION_SCHEMA` を使って「列がまだ存在しない場合のみ」追加処理を行うため、Kazumax様のPCに入っている既存データが上書きされたり消えたりするリスクはゼロです。

## 5. CC(P3)に課す検証条件
CC(P3)はコード修正後、以下の2パターンの起動テストを必ず行うこと。
1.  **既存DB起動テスト**: 既存の列が存在する状態で起動し、エラーが出ずにスキップされること（冪等性の確認）。
2.  **新規構築テスト**: 意図的に対象のテーブル（または列）をDROPした状態で起動し、動的SQLによって正しく列が追加され、アプリが立ち上がること。

---
**Kazumax様へ:**
この方針で問題なければ、合図文を使ってDexへ事前監査（P2）を依頼してください。
