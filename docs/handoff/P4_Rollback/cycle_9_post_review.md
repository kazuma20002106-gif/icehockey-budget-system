# [C9: Dex(P4) ⇒ CC(P3) Take2] Cycle 9 事後レビュー差し戻し

## 判定

**NG**

詳細レビュー:

- `docs/handoff/P4_Dex_Review/cycle_9_post_review.md`

## 差し戻し先

**CC**

Airが越権実装した変更だが、修正実装は役割分担どおりCCが担当する。
Airは必要に応じて仕様意図の補足のみ行う。

## 修正必須

1. `replace.py`, `test.py`, `src/main/resources/templates/test.py` を削除または作業外へ退避する。
2. `AGENTS.md` など今回対象外の差分をコミット対象から外す。文字化け/NULL混入が必要なら別サイクルで扱う。
3. `ExcelExportService.java` のtrailing whitespaceを除去する。
4. 可能なら金額出力時の `(int)` キャストを避け、long金額を安全に出力する。
5. `.\mvnw.cmd -q -DskipTests compile` を実行し、結果をP3へ記録する。
6. `docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take2.md` を作成して再提出する。

## 注意

様式2-2-1の主要セル座標とカテゴリ別合算の方向性はDex確認では概ね正しい。
今回の差し戻しは主に作業ツリー安全性と検証不足に対するもの。
