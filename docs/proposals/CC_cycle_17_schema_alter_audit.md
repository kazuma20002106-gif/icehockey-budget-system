[C1: CC(P3) ⇒ Air(P1)/Dex(P2)]

# ＋α提案: schema.sqlの`ADD COLUMN IF NOT EXISTS`棚卸し

## 背景

Cycle 17で`is_printed`列を追加する際、指示書どおり`ALTER TABLE projects ADD COLUMN IF NOT EXISTS is_printed ...`を実装したところ、実機のMySQL 8.0.46で構文エラーになりました。調査の結果、`ADD COLUMN IF NOT EXISTS`はMariaDB固有構文であり、MySQL(Oracle版)では非対応と判明しました。

さらに実機で単体テストしたところ、**Cycle 8で追加された`accommodation_nights`・`travel_misc_cost`・`travel_misc_days`の同じ構文のALTER文も、起動のたびに毎回サイレントに構文エラーで失敗し続けていた**ことを確認しました（`spring.sql.init.continue-on-error=true`のため起動自体は継続し、誰も気づかないまま今日に至っていたと推測されます）。これらの列が実際にDBに存在するのは、過去のどこかの時点で別経路（手動ALTER等）で追加されたためと推測されます。

## 今回のCycle 17での対応範囲

`is_printed`列のみ、`INFORMATION_SCHEMA.COLUMNS`存在確認＋`PREPARE`/`EXECUTE`による動的SQLの冪等追加方式に修正済みです（実機で新規追加・再実行時の冪等性の両方を確認済み）。

## 提案

Cycle 8由来の`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`（`accommodation_nights`, `travel_misc_cost`, `travel_misc_days`）についても、同様に動的SQL方式へ書き換えることを提案します。現状は「たまたまDBに列が存在するので実害はない」状態ですが、**新しい環境（例: Phase2のVPS本番DB）にこのschema.sqlから初回構築した場合、これらの列が実際には作成されずアプリが起動時エラーになるリスク**があります。

- 対応候補ファイル: `src/main/resources/schema.sql`
- リスク区分: DBスキーマ変更のため、本プロジェクトの危険領域ルールどおりAir(P1)方針確認→Dex(P2)事前監査→CC(P3)実装→Dex(P4)レビューの完全プロセスを推奨します。
- 優先度: Phase2 VPS本番環境構築（新規DB構築）の前に対応することを推奨します。
