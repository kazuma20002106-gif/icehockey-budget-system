# CURRENT STATUS

## Cycle 22 Take4 P4待ち: 360pxヘッダー幅修正・実画面確認は未確認（2026-08-04）

- **Take4修正内容**: Dex提示のCSSをそのまま適用。狭幅で`.navbar-brand`と`.header-right-group`の両方に`flex: 0 0 100%`を明示し、ブランドは省略記号、右側3要素（？使い方・ヘルプ・操作ユーザー）を優先表示。`layout.html`はCSSバージョンクエリ（`?v=7`）のみ変更。
- **検証**: `mvnw -q -DskipTests compile`成功、`mvnw -q test`成功（13件、exit 0）。禁止ファイル差分なし、`app.version=v2.6.2`維持。
- **重要: 実画面確認が今回も未実施（理由が前回までと異なる）**: Browser pane・Claude in Chromeともに接続不可（Browser paneは`navigate`/`tabs_create`/`screenshot`すべて失敗、Claude in Chromeは拡張機能未接続）。開発サーバー自体はポート8080で起動しHTTP 200を返すこと、配信CSSに正しいTake4修正が含まれていることは`curl`で確認済みだが、**360px/1280pxでの実際のレイアウト・操作ユーザーdropdown展開の目視確認はCC側で実施不能だった。**詳細は `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take4.md` を参照。
- **次担当**: Dex(P4)。上記Take4報告を読み、実機（headlessブラウザ等）で360px/1280pxの最終確認を行いOK/NGを判定する。
- **完全不動規約**: DB、保存、金額、Excel、Mapper、既存URL、hidden input、POST先、`app.version` は変更禁止（維持確認済み）。

## Current Cycle

- Cycle 22: 初見利用者向けガイド・ツールチップ統合改善 (P4 Take4レビュー待ち・実画面確認はDex側に依存)

## 次の担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take4.md` を読み、360px幅で操作ユーザーdropdownが完全表示・操作可能か、1280pxで既存表示が維持されているかを実機確認し、OK（`docs/handoff/P4_Dex_Review/`）またはNG（`docs/handoff/P4_Rollback/`）を判定すること。

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `manuals/AI_TEAM_WORKFLOW.md`
6. `manuals/WORKFLOW_RULES.md`
7. `docs/handoff/P4_Rollback/cycle_22_first_use_guide_and_tooltips_take3.md`
8. `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take4.md`

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行の禁止
- `git add .` の自動実行の禁止
- 作業中の他AI/ユーザー差分を勝手に見落として戻さないこと
- 金額計算、Excel出力、DB、mapper、schemaに触る変更の完全禁止（本Cycle要件による）
- `app.version` の変更禁止

## 履歴アーカイブ
- 古い進捗や過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` を参照
- 各サイクルの正式記録は `docs/handoff/P1_Air_Blueprint/`, `docs/handoff/P2_Dex_to_CC/`, `docs/handoff/P3_CC_to_Dex/`, `docs/handoff/P4_Dex_Review/`, `docs/handoff/P4_Rollback/` に保存済み
