[C23: CC(P3) ⇒ Dex(P4) Take2]

# Cycle 23 Take2 P3実装報告: 秘密値マスク・DB healthcheck・PATH案内の修正

対象差し戻し: `docs/handoff/P4_Rollback/cycle_23_docker_pilot_environment.md`
app.version: **v2.7.1**

## 1. 対象範囲

P4差し戻しの3点（P1×2、P2×1）と`app.version`更新のみを修正した。Take1でP4合格済みのDocker主要機能（DB隔離、非root、schema、volume、HTTP、禁止領域DIFF）には手を加えていない。ホスト実DBへはTake2でも**一度も接続していない**。

## 2. 修正内容

### 2.1 【P1】秘密情報のマスク

`docs/handoff/P3_CC_to_Dex/cycle_21_comprehensive_safety_and_ui_take4.md` の2か所（18行目・22行目）を `-p[REDACTED]` へ置換した。

- 18行目: `mysql -u root -p[REDACTED] -e "SHOW BINARY LOGS;"`
- 22行目: `mysqlbinlog -vv --read-from-remote-server -h127.0.0.1 -uroot -p[REDACTED]`

binlog調査の手順説明としての意味は保持している（コマンド構造・調査対象・結論の記述は無変更）。

**残存確認（旧実値を表示せずに実施）:**

- 作業ツリーの tracked file 全体を `git grep -I -F` で完全一致検索 → **0件（PASS）**
- CCクルー観点Aが独立に再検索（tracked＋未追跡の`docs/`・`manuals/`・`src/`・ルート直下・`.claude/`まで走査）→ **0件（PASS）**
- 今回の差分に旧実値の**追加行(+)は0件**。削除行(-)のみ（＝値を除去したことを示すdiff）。

push後の`origin/main` snapshotでの0件確認は、本報告のcommit後に実施し「6. commit / push」へ記載する。

新旧いずれのパスワードも本報告書には記載していない。

### 2.2 【P1】DB healthcheckの認証誤判定

`compose.yaml` のdb healthcheckを、認証成功まで確認する方式へ変更した。

変更前（`mysqladmin ping`）は、誤ったパスワードでもサーバが生きていればexit 0を返すため、実質「サーバ生存確認」でしかなかった。Dex指摘のとおりであり、説明コメントと実挙動も乖離していた。

変更後:

```yaml
test:
  - CMD-SHELL
  - mysql --protocol=TCP -h 127.0.0.1 -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE" -N -e "SELECT 1" > /dev/null 2>&1
```

説明コメントも実挙動と一致する内容へ書き換えた。秘密値はコンテナ環境変数から参照し、composeへ直書きせず、`> /dev/null 2>&1`でログへも出力しない。

**期待する状態遷移の実測（コンテナ内で実行）:**

| 条件 | 期待 | 実測 |
|---|---|---|
| 専用ユーザー・正しいパスワードで`SELECT 1` | 成功(0) | **exit=0** |
| 専用ユーザー・誤ったパスワード | 失敗(≠0) | **exit=1** |
| 誤ったユーザー名 | 失敗(≠0) | **exit=1** |
| 参考: 旧`mysqladmin ping`＋誤パスワード | （誤判定） | exit=0（Dex指摘を再現） |

**Docker側のhealthcheck記録:**

```
docker inspect budget-system-db-1
=> healthy / FailingStreak=0
   health log: exit=1  exit=0  exit=0
```

MySQL起動途中では`exit=1`（unhealthy判定）、起動完了後に`exit=0`へ遷移しており、**実際に状態を識別している**ことが確認できる。旧方式では起動直後から0を返していた。

### 2.3 【P2】PATH未登録時のクイックスタート案内

`DOCKER_QUICKSTART.md` の「1. Docker が使えるか確認する」に、Windows PowerShell向けの手順を追記した。

- 手順1: 新しいターミナルを開いて `docker version` を再確認する
- 手順2: それでも見つからない場合、`$env:PATH = "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin;" + $env:PATH` で**そのPowerShellセッションだけ**PATHへ追加する
- 「今開いているPowerShellウィンドウの中だけ有効」「ユーザー環境変数・システム環境変数は変更しません」を明記
- Docker Desktopの場所が異なる場合の補足も記載
- `copy .env.example .env` が Windows の PowerShell / コマンドプロンプト用であることを明記

`docker compose down -v` が通常手順へ混入していないこと、名前付きvolumeがバックアップではない旨の注意が維持されていることも確認済み（CCクルー観点BでPASS）。

### 2.4 app.version

`src/main/resources/application.properties` の `app.version` を **v2.7.0 → v2.7.1** へ更新（この1行のみ。他キーは無変更）。

## 3. Take2受入確認の結果

| # | 受入条件 | 結果 |
|---|---|---|
| 1 | Kazumaxから値を含まない「ローテーション完了」の合図 | **未達**（下記4.参照。Kazumax作業と並行実施中） |
| 2 | 現在のtracked fileで旧実値0件 | **PASS**（push後snapshotは6.に記載） |
| 3 | `.env`がignored・untrackedのまま | **PASS**（`git check-ignore`で無視、`git ls-files .env`は空） |
| 4 | 誤認証で失敗し、正しい資格情報の`SELECT 1`成功時だけhealthy | **PASS**（2.2の実測表・health log） |
| 5 | `config --quiet` / `build` / `up -d --wait` 成功 | **PASS**（すべて成功） |
| 6 | app/db running、db healthy、接続先`db`、DB非root、app非root、3306非公開 | **PASS**（下記） |
| 7 | 主要5画面が200 | **PASS** |
| 8 | 既存volumeと`C23_DOCKER_TEST_`データが保持、`down -v`未実行 | **PASS** |
| 9 | ログに接続・schemaエラーなし | **PASS** |
| 10 | 禁止領域DIFF 0件、`git diff --check`、compile成功、source/targetとも`v2.7.1` | **PASS** |
| 11 | PATH未登録時のPowerShell手順を再現できる | **PASS**（CC自身がこの手順でCLIを使用） |

### 実測値の詳細

```
docker compose ps
  budget-system-app-1  Up  127.0.0.1:18080->8080/tcp
  budget-system-db-1   Up (healthy)  3306/tcp, 33060/tcp     ← 3306はhost非公開

app実行ユーザー : uid=999(appuser) gid=999(appgroup)          ← 非root
DB接続コンテキスト: budget_pilot / pilot_user@% / 8.4.11        ← 専用DB・非root・8.4系

HTTP: /guide 200  /activity 200  /dashboard 200  /export 200  /members 200  / 302

volume保持: budget-pilot-db-data に C23_DOCKER_TEST_MEMBER が残存
業務データ : projects=0  expenses=0                            ← ホスト実データの混入なし

ログ: Started BudgetSystemApplication in 26.313 seconds
      接続/schemaエラー なし / 旧ホストDB参照 なし / 旧秘密値 なし
```

### ビルドと成果物

- `mvnw.cmd -q -DskipTests clean compile` **成功**（source/target とも `app.version=v2.7.1`）
- `git diff --check` **PASS**
- 新image: `budget-system-app:latest` = `7fe5a4b4dd58` / `mysql:8.4.11` = `b3b90af2a655`
- image内JARの`application.properties`は環境変数参照のみ、`app.version=v2.7.1`、`continue-on-error=false`
- image内JAR全体のbinary grepで旧実値 **0件（PASS）**

`clean`実行時、Take1と同様にOneDriveが`target/`のディレクトリハンドルを保持して削除に失敗した。`target/`がgitignore対象のビルド生成物であることを`git check-ignore`で確認したうえで削除し、再実行して成功させた。追跡ファイルへの影響なし。

`mvnw test`はP2指示書・Take3命令の禁止事項（ホストDBへの書込みリスク）のため**実行していない**。

## 4. Kazumaxのパスワードローテーションについて

受入条件1は**まだ満たされていない**。Kazumaxによるローテーション完了の合図を受領していないため、本報告時点では未達として報告する。

CC側は指示どおり以下を厳守した。

- ホスト実DBへ接続していない（旧値・新値のいずれでも試行していない）。
- 新旧どちらのパスワードもチャット・Git・handoff・Dockerの`.env`へ書いていない。
- Docker用`.env`にはpilot専用のランダム生成値のみを使用しており、ホストDBの値とは無関係。
- Git履歴の書換え・force pushは実行していない（P4差し戻し3.のとおり、別途明示承認が必要な破壊的作業のため）。

CCクルー観点Aも「マスクだけでは露出は解消せず、push済み履歴に旧値が残る。ローテーションが本質的対処」と独立に指摘しており、P4差し戻しの判断と一致している。**本人手渡しはローテーション完了後、かつP4 OK後**とする。

## 5. CCクルー3観点レビュー結果

### 観点A: 秘密情報 — 総合判定「要修正」

5項目すべてPASS（tracked file 0件、マスク2か所の妥当性、`.env`未追跡、新規持ち込みなし、compose/quickstartに実値なし）。

「要修正」とされた2点はいずれも**Take2の作業品質の問題ではない**:

1. 旧実値が`origin/main`のcommit履歴（`33640e1`, `5451304`, `a943356`）に残存 → ローテーションが本質的対処。P4差し戻しの方針と同一で、CCの権限外。
2. レビュー実施時点でマスク修正が未コミットだった → 本報告と同時にcommit/pushして解消する。

### 観点B: DB healthcheckとクイックスタート — 総合判定「OK」

6項目すべてPASS。`$$`展開がcomposeとコンテナ内shellで正しくラウンドトリップすることを`docker inspect`で確認、誤資格情報でexit 1・正資格情報でexit 0を実測、health logに秘密値の出力がないことも確認済み。PATH手順4要件（新ターミナル再確認／セッション限定PATH追加／システムPATH不変の明示／`copy`がWindows用の明記）すべて充足。

任意の改善提案として「`-p"$MYSQL_PASSWORD"`はコンテナ内`ps`に一時的に平文で載るため`MYSQL_PWD`経由がより堅い」との指摘があった。P4差し戻し4.が`mysql --protocol=TCP ... -e "SELECT 1"`相当を指定しているため**今回はP4仕様に忠実な実装を維持**し、変更していない。Dexが採用を望む場合はTake3で対応する。

### 観点C: 変更範囲・禁止領域DIFF — 総合判定「要修正」

7項目すべてPASS（許可範囲内、`application.properties`は1行のみ、`schema.sql`差分なし、禁止領域0件、take4.mdはマスク2か所のみ、他AI差分7ファイル＋未追跡50件超を保全、`git diff --check`合格、`git stash`空）。

「要修正」の理由はレビュー時点で本Take2報告書が未作成だった点のみ。本ファイルの作成で解消する。

## 6. commit / push

（コミット後に追記）
