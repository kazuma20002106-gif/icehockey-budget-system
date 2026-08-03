# CURRENT STATUS

> [!CAUTION]
> **Kazumax代表からの全体絶対ルール**
> 入力が簡単になっても、合算が正しくなければツールとして意味がない。合算が正常に行われているかを第一優先にする。

## Current Cycle

- Cycle 20: 年度末Excel完全監査・年度/原本値/空きセル残存修正

## 現在地

- Cycle 18: P4 OK。Kazumax確認を経て完了扱い
- Cycle 19: Air(P1) によるBlueprint（要件と12の必須受入確認・不可触領域設計）の構築が完了。
- Air(P1): 完了（`docs/handoff/P1_Air_Blueprint/cycle_19_input_output_role_separation.md` に保管済み）
- Dex(P2): 事前監査完了。Air案の旧年度まとめ説明、旅行雑費固定表現、暗黙印刷フィルタ、hidden/query保持を補正し、CC向け最終指示書を作成済み
- CC(P3): 実装・検証・CCクルー3観点セルフレビュー完了。app.version=v2.5.1。`docs/handoff/P3_CC_to_Dex/cycle_19_input_output_role_separation.md` に報告書を保存済み
- Dex(P4): commit `466ad9d` をレビューし、通常preview往復で6検索条件が失われるP1要件漏れを確認。Take2差し戻し
- CC(P3) Take2: `/export/preview`往復での6条件（year/budgetTypeId/month/targetCategory/projectName/printedStatus）保持を修正。app.version=v2.5.2。CCクルー3観点セルフレビュー完了。`docs/handoff/P3_CC_to_Dex/cycle_19_input_output_role_separation_take2.md` に報告書を保存済み
- Dex(P4) Take2: 当初DIFFレビューOKとしたが、Kazumax実機確認で一括選択・印刷状態ボタン・旧簡易出力導線の問題が判明したためOKを取り消し。
- Dex(P4) Take2再監査: **NG / Take3差し戻し**。`export/index.html`の操作用scriptがレイアウト取込範囲外にあり、`toggleAll`/`bulkPrintStatus`がブラウザへ届いていないことを実機再現。旧簡易出力は画面から外しlegacy URLだけ維持する判断。通常previewの6条件往復は合格。
- Dex年度末Excel厳密監査: 2026年度公式Excel27シートを実生成。様式2-5は8事業・44名の44/44名で漏れなし、主要支出合計317,568円も一致。一方、2-2-1×3の年度が令和7年度のまま、2-3未対象行に旧金額、2-5/2-6空きセルに原本値936が残るため、Excel修正はCycle 19へ混ぜず次サイクル最優先候補としてバックログ化。

- CC(P3) Take3: `export/index.html`の操作用script/styleをレイアウト取込範囲(`content=~{::div}`が抽出する単一div)内へ移し、旧・簡易年度まとめカードを画面から削除。legacy URL `/activity/export/year`・Controller・Excel処理は無変更。app.version=v2.5.3。実ブラウザで一括選択・印刷済みダイアログ・キャンセル非送信・0件警告・旧カード非表示・legacy URL・6条件preview往復・日本語エンコード・ReferenceErrorなしの10項目を確認。CCクルー3観点セルフレビュー完了。`docs/handoff/P3_CC_to_Dex/cycle_19_input_output_role_separation_take3.md` に報告書を保存済み
- Dex(P4) Take3: **P4 OK / 実装差し戻し不要**。DIFF、レイアウト展開後HTML、実ブラウザ10項目、legacy Excel応答、選択ID限定更新、compile、app.version=v2.5.3を確認。さらに2026年度8件を開始前記録し、ID 24だけを実DBで未印刷→印刷済へ更新して他7件不変を確認後、同じIDを未印刷へ復元。復元後8件は開始前と完全一致し、実データ残存なし。詳細は`docs/handoff/P4_Dex_Review/cycle_19_input_output_role_separation_take3.md`
- Cycle 19: **完了**。Kazumaxにしかできない必須確認は残っていない
- CC(P3) Cycle20: Air試作品を項目ごとに採用/不採用判定して作り直し。占有行/ブロックの広範囲blank化は不採用、書込列限定の`clearColumnsAcrossRows`へ差し替え。`evaluateFormulasAndRecalculate`は年度末公式出力1箇所のみに限定し例外を握りつぶさない構造に変更。`.gemini`等の外部固定パス書出しテストは削除しメモリ内検証へ全面書き直し。実HTTPで2026年度公式Excelを実生成しopenpyxl検証: 27シート、2-5:44名、2-6:10名/交通費21,828円/宿泊費91,300円、AC25=317568円、K33/T33=605000/750239から解消、値936の残存0件、数式エラー0件。DB非更新確認済み。app.version=v2.5.4。CCクルー3観点セルフレビュー完了（軽微指摘1件を次サイクル申し送り）。`docs/handoff/P3_CC_to_Dex/cycle_20_annual_excel_integrity.md` に報告書を保存済み

## 次の担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_20_annual_excel_integrity.md` を読んでDIFFレビューする。Air試作の採用/不採用判定の妥当性、書込列限定クリアの安全性、数式評価の適用範囲・例外方針、936残存0件の実測、DB非更新を重点確認

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `manuals/AI_TEAM_WORKFLOW.md`
6. `manuals/WORKFLOW_RULES.md`
7. `docs/handoff/P4_Rollback/cycle_19_input_output_role_separation_take2.md`（第6〜7章: 実測値・Cycle 20必須範囲）
8. `docs/proposals/backlog_ui_ux.md`（第3章: 年度末Excel監査の実測所見）
9. `docs/handoff/P4_Dex_Review/cycle_19_input_output_role_separation_take3.md`（Cycle 19完了記録）
10. `docs/handoff/cycle_20_kazumax_to_air_requirements.md`（Kazumax確定要件）
11. `docs/handoff/P1_Air_Blueprint/cycle_20_annual_excel_integrity.md`（Air試作品の設計記録）
12. `docs/handoff/P2_Dex_to_CC/cycle_20_annual_excel_integrity_instructions.md`（CC向け最終指示書）

## Cycle 19 重要ルール

- 活動一覧は入力・編集中心、出力画面は対象選択・プレビュー・Excel出力・印刷状態管理中心にする。
- Excelダウンロードだけで自動的に印刷済みにしない。実印刷後に利用者が明示操作する。
- 年度末一括出力は様式2-1〜2-6を従来どおり含み、対象条件と合計を変えない。
- 個人雑費の画面注記は削除候補だが、DB値・既存値保持・様式2-6・原本Excel欄は削除しない。
- 旧出力URL・legacy `/export` は即時削除しない。
- Air(P1) -> Dex(P2) -> CC(P3) -> Dex(P4) の完全プロセスを通す。

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行の禁止
- `git add .` の自動実行の禁止
- 作業中の他AI/ユーザー差分を勝手に見落として戻さないこと
- 金額計算、Excel出力、DB、mapper、schemaに触る変更は、Air(P1) -> Dex(P2) -> CC(P3) -> Dex(P4) の完全プロセスを通す

## 履歴アーカイブ
- 古い進捗や過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` を参照
- 各サイクルの正式記録は `docs/handoff/P1_Air_Blueprint/`, `docs/handoff/P2_Dex_to_CC/`, `docs/handoff/P3_CC_to_Dex/`, `docs/handoff/P4_Dex_Review/`, `docs/handoff/P4_Rollback/` に保存済み
