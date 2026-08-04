# CURRENT STATUS

## Cycle 23 P4待ち: Dockerローカル試運転 実装・実機検証完了（2026-08-04）

- **P3実装完了**: 許可8ファイル（Dockerfile / compose.yaml / .dockerignore / .env.example / .gitignore / DOCKER_QUICKSTART.md / application.properties / schema.sql）を実装。`app.version=v2.7.0`。
- **Docker実機検証: 全項目合格**。Engine応答（Docker Desktop 4.84.0 / Client v29.6.2 / Compose v5.3.1）、`build --no-cache`成功、`up -d --wait`成功、db healthy、`/guide`・`/activity`ほか主要GET全て200、`down`→`up`でvolume保持をダミーデータ1件で確認。
- **DB隔離確認済み**: 接続先は`jdbc:mysql://db:3306/budget_pilot`。`SELECT DATABASE(),CURRENT_USER(),VERSION()`＝`budget_pilot` / `pilot_user`(非root) / `8.4.11`。app実行は`uid=999(appuser)`で非root。3306はhost非公開、appは`127.0.0.1:18080`限定。業務テーブルは全て0件でホスト実データの混入なし。ホスト本物DBへは未接続。
- **CCクルー3観点**: A(秘密情報・DB隔離)=Docker実装は全PASS／既存漏洩により総合「要修正」、B(Docker・配布物)=OK（healthcheckの`CMD`→`CMD-SHELL`実バグを検出し修正済み）、C(禁止領域DIFF)=OK（禁止領域差分ゼロ、他AI差分も保全）。
- **要判断（Cycle 23対象外の既存漏洩）**: `docs/handoff/P3_CC_to_Dex/cycle_21_comprehensive_safety_and_ui_take4.md`にホストDB実パスワードが平文で残存し、旧`application.properties`の実値も初回コミット以降のgit履歴にpush済み。CCは許可範囲外のため未修正。**本人手渡し前にパスワードローテーションの要否をKazumax/Dexが判断すること。**
- **通常起動への影響**: DB接続が環境変数必須になったため、Docker外の`mvnw spring-boot:run`と`mvnw test`はenv未設定だと起動失敗する（意図的なfail-fast、P2承認済み）。`DOCKER_QUICKSTART.md`に明記。
- **P3報告**: `docs/handoff/P3_CC_to_Dex/cycle_23_docker_pilot_environment.md`
- **配布境界**: registryへのpush・本人への手渡しはいずれも未実施。手渡しはP4 OK後。

## Current Cycle

- Cycle 23: Dockerローカル試運転・本人手渡し（P4レビュー待ち）

## 次の担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_23_docker_pilot_environment.md` を読み、Docker実起動・接続先・secret残存・非root・schema全成功・volume保持・HTTP到達・禁止領域DIFFを再確認する。あわせて上記「既存漏洩」への対応方針を判断すること。P4 OK後に限り本人手渡しを許可する。

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `manuals/AI_TEAM_WORKFLOW.md`
6. `manuals/WORKFLOW_RULES.md`
7. `docs/handoff/P2_Dex_to_CC/cycle_23_docker_pilot_environment_instructions.md`
8. `docs/handoff/P2_Dex_to_CC/cycle_23_docker_pilot_environment_instructions_take3.md`
9. `docs/handoff/P3_CC_to_Dex/cycle_23_docker_pilot_environment.md`

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行禁止
- `git add .` の自動実行禁止
- 作業中の他AI／ユーザー差分を勝手に変更・破棄しない
- 金額計算、Excel出力、DB構造、Mapperの業務ロジック変更禁止
- ホスト上の実本番データベース・データへの侵入・改ざん禁止
- 無関係な第三者や一般Webレジストリ(公開Docker Hub)へのコンテナ無謀大放流の禁止
- Docker CLI/Engine未確認のまま、Docker実機検証成功と報告しない
- P4 OK前に本人へフォルダ・imageを手渡さない

## 履歴アーカイブ
- 古い進捗や過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` および各 handoff フォルダを参照
