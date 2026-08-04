[C23: CC(P3) ⇒ Dex(P4)]

# Cycle 23 P3実装報告: Dockerローカル試運転環境

対象指示書: `docs/handoff/P2_Dex_to_CC/cycle_23_docker_pilot_environment_instructions_take3.md`（および元P2指示書）
app.version: **v2.7.0**

## 1. 変更ファイルと目的

### 新設（5件）

| ファイル | 目的 |
|---|---|
| `Dockerfile` | multi-stage build。builder=`maven:3.9.16-eclipse-temurin-17`、runtime=`eclipse-temurin:17-jre`。非rootユーザー`appuser`で実行。最終imageへMaven/ソース/.git/docs/tmp/ログ/.envを含めない |
| `compose.yaml` | app+MySQLを専用network`budget-pilot-net`で隔離。DBはhost非公開、appは`127.0.0.1:18080`限定。必須変数は`${VAR:?}`で欠落時失敗 |
| `.dockerignore` | build contextから`.git`/`.env`/`target`/`tmp`/ログ/`docs`/IDE設定/`src/test`を除外。`pom.xml`と`src/main`は除外していない |
| `.env.example` | pilot専用のダミー値と説明のみ。ホスト実DBの接続値・パスワードは転載していない |
| `DOCKER_QUICKSTART.md` | 初回設定〜起動〜停止〜更新の最短手順。`down -v`は通常手順から分離し注意書きを明記 |

### 変更（3件）

| ファイル | 変更内容 |
|---|---|
| `.gitignore` | `.env` / `.env.*` / `!.env.example` を追記。既存の除外ルールは削除していない |
| `src/main/resources/application.properties` | DB接続を環境変数必須参照へ（実値を削除）、`continue-on-error=false`、`app.version=v2.7.0` |
| `src/main/resources/schema.sql` | 先頭の`CREATE DATABASE IF NOT EXISTS budget_system` / `USE budget_system;`の2行を削除（＋意図コメント追加）のみ |

`src/main/java/`、`mapper/*.xml`、`書類.xlsx`、`templates/`、`static/`への差分は**ゼロ**（CCクルー観点Cで独立確認済み）。

## 2. Docker Desktop / CLI / Engine の実確認結果

P2指示書1.1の記載（ディレクトリが空、CLI未確認）から状況が変化していた。

- `Get-Command docker`: **PATH未登録**
- `docker.exe` 実体: **あり** — `C:\Users\kazum\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe`
- Client: **v29.6.2** / API 1.55
- Server(Engine): **Docker Desktop 4.84.0 (234817)**、Engine v29.6.2、containerd v2.2.5、runc 1.3.6 — **応答あり**
- `docker compose version`: **v5.3.1**

### CLIの使用方式

Take3の許可に従い、**セッション内のみ**PATHへ`...\DockerDesktop\resources\bin`を前置して実行した。ユーザーPATH・システムPATHは変更していない。Docker Desktop本体・WSL・インストーラー・Windows設定はCC側で一切操作していない。

なお初回の`docker compose build`は`docker-credential-desktop`がPATHに無いため失敗した。同ヘルパーは上記binディレクトリに存在するため、セッションPATH前置で解消した（設定変更なし）。

## 3. 使用イメージの実タグとimage ID

| 用途 | タグ | image ID |
|---|---|---|
| アプリ（ビルド成果） | `budget-system-app:latest` | `dfc51dfc7026` |
| DB | `mysql:8.4.11` | `b3b90af2a655` |
| builder | `maven:3.9.16-eclipse-temurin-17` | （build時のみ、最終imageに含まれない） |
| runtime base | `eclipse-temurin:17-jre` | 同上 |

P2指定の`mysql:8.4.11`をそのまま使用でき、`mysql:8.4`へのフォールバックは不要だった。

## 4. DB隔離の証拠（秘密値は伏せる）

### 接続先

`docker compose config`の解決結果:

```
SPRING_DATASOURCE_URL: jdbc:mysql://db:3306/budget_pilot?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Tokyo&characterEncoding=UTF-8
```

- 接続先は**Compose内の`db`サービス**。`localhost` / `host.docker.internal` / ホストIPは使用していない（解決済みconfigをgrepしてPASS確認）。
- ports解決結果: `host_ip: 127.0.0.1` / `published: "18080"`。**3306はhostへ未公開**（`docker compose ps`でも`3306/tcp`とだけ表示され、host bindingなし）。

### コンテナ内での実測

```
SELECT DATABASE(), CURRENT_USER(), VERSION();
=> budget_pilot    pilot_user@%    8.4.11
```

**専用DB・非rootの専用ユーザー・MySQL 8.4系**を満たす。

### アプリ実行ユーザー

```
docker compose exec app id
=> uid=999(appuser) gid=999(appgroup) groups=999(appgroup)
```

**rootではない**。

### ホスト実データの非混入

Docker専用DBの件数:

```
projects: 0   members: 0(検証前)   expenses: 0   project_participants: 0
project_summary_expenses: 0   budget_allocations: 0
budget_types: 3 (schemaの許可済み初期マスタ)
users: 1 (schemaの初期操作ユーザー。Kazumax判断により維持)
```

業務データは全て0件で、ホストの実活動データ（Cycle 21時点でprojects 9件等）は**一切取り込まれていない**。

### ホスト本物DBへの不干渉

- ホストMySQLは別プロセス（PID 8020）が3306でリッスン中だが、Dockerのdbコンテナは3306をhostへ公開していないため**衝突・混線なし**。
- アプリログを走査し、`localhost:3306`および旧DB名`budget_system`への参照が**存在しないこと**を確認（PASS）。
- CC側からホスト本物DBへは**一度も接続していない**。

## 5. 検証結果一覧

### 静的・ビルド

| 項目 | 結果 |
|---|---|
| 変更ファイルが許可8ファイル範囲内 | PASS（CCクルー観点Cで独立確認） |
| `git diff --check` | PASS（whitespaceエラーなし） |
| `mvnw.cmd -q -DskipTests clean compile` | **成功** |
| source と `target/classes` の`app.version=v2.7.0`一致 | PASS |

`clean`実行時、OneDrive同期が`target/`配下のディレクトリハンドルを保持しており削除に失敗した。`target/`はgitignore済みのビルド生成物であることを`git check-ignore`で確認したうえで削除し、再実行して成功させた。ソース・追跡ファイルには影響なし。

### 旧DB秘密値の残存確認（値は出力していない。PASS=残っていない）

| 対象 | 結果 |
|---|---|
| 新設・変更した8ファイル全て | **PASS** |
| `target/classes/` | **PASS** |
| ビルド済みJAR全体（binary grep） | **PASS** |
| image内JARの`application.properties` | **PASS**（環境変数参照のみ） |
| tracked file全体（`git grep`） | **FAIL**（下記6.を参照。Cycle 23対象外の既存漏洩） |
| 今回のcommit差分（新規に秘密値を持ち込んでいないか） | **PASS**（追加行0件。`application.properties`の**削除行1件のみ**＝実値を除去したことを示すdiffであり、新たな漏洩ではない） |

image内JARから抽出した実際の内容:

```
spring.datasource.url=${SPRING_DATASOURCE_URL}
spring.datasource.username=${SPRING_DATASOURCE_USERNAME}
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD}
app.version=v2.7.0
spring.sql.init.continue-on-error=false
```

同JAR内の`schema.sql`先頭からも`CREATE DATABASE`/`USE`が消えていることを確認した。

### Docker実機

| 項目 | 結果 |
|---|---|
| `docker version` Client/Server両応答 | **PASS** |
| `docker compose config --quiet` | **成功**（秘密値は本書へ貼っていない） |
| `docker compose build --no-cache` | **成功** |
| `docker compose up -d --wait` | **成功** |
| `docker compose ps` app/db running、db healthy | **PASS** |
| appログに接続失敗・schemaエラー・旧host DB URLなし | **PASS**（`Started BudgetSystemApplication in 27.855 seconds`） |
| 主要テーブル10件の存在 | **PASS**（budget_allocations/budget_types/expenses/members/project_participants/project_summary_expenses/projects/route_master/system_settings/users） |
| 一意制約`uq_expenses_project_participant`の存在 | **PASS**（1件検出） |
| `GET /guide`, `GET /activity` | **200**（加えて`/dashboard`,`/export`,`/members`も200、`/`は`/dashboard`へ302） |
| `docker compose down`後の再起動でvolume保持 | **PASS**（下記） |
| app実行ユーザーがroot以外 | **PASS**（uid=999 appuser） |
| image/JARへ旧DBパスワードなし | **PASS** |

### volume保持テスト

Docker専用DBだけへ`C23_DOCKER_TEST_`接頭辞のダミー名簿を1件登録（`POST /members/add` → 200。日本語フォーム送信はこの環境のcurl制約によりPython urllib＋UTF-8で実施）。

```
登録直後      : 1  C23_DOCKER_TEST_MEMBER  C23_DOCKER_TEST_PLACE
docker compose down 実行（-v は未使用）
volume確認    : budget-pilot-db-data が残存
docker compose up -d --wait 実行
再起動後      : 1  C23_DOCKER_TEST_MEMBER  C23_DOCKER_TEST_PLACE   ← 保持を確認
再起動後HTTP  : /guide /activity /dashboard /export いずれも200
```

ホストDBへは一切書き込んでいない。

## 6. 重要な発見: Cycle 23対象外の既存漏洩（要判断）

P2指示書6.1の秘密値確認で、**tracked fileにホストDBの実パスワードが残存**していることを検出した。

- 該当: `docs/handoff/P3_CC_to_Dex/cycle_21_comprehensive_safety_and_ui_take4.md`（CC自身がCycle 21で作成し、push済み）
- 内容: binlog調査時の接続コマンドに`-p<実パスワード>`の形で2箇所記載
- さらにCCクルー観点Aの調査により、**旧`application.properties`の実パスワードが初回コミット`33640e1`以降のgit履歴に残り、GitHubのremoteへpush済み**であることも判明した。

これはCycle 23のDocker実装の欠陥ではなく既存の漏洩だが、Cycle 23の目的（秘密情報の成果物からの除去）と直結する。**Cycle 23の許可ファイル8件の範囲外のため、CCは独断で修正していない。** また、要件書「既に履歴へ入った認証情報は…履歴書換えや本物DBのパスワード変更をCCが独断で行わない」に従い、履歴書換え・パスワード変更も実施していない。

Dex(P4)／Kazumaxへの推奨対応:

1. **ホストMySQL該当アカウントのパスワードローテーション（本質的対処）**。push済みのため履歴書換えだけでは回収を保証できない。
2. 上記handoff文書の該当2箇所をマスクへ置換。他のdocsにも同種のログが無いか横断確認。
3. 本人手渡しの前に1.を完了させるか、少なくともKazumaxが明示的にリスクを了承すること。

## 7. CCクルー3観点レビュー結果

P2指示書の「CCクルー利用: 必須」に従い、読み取り専用の3クルーを並行実行した。

### 観点A: 秘密情報・DB隔離 — 総合判定「要修正」

Docker実装8観点（環境変数化、`.env.example`の非転載、`.gitignore`、接続先が`db`、非rootユーザー、3306非公開、`${VAR:?}`必須化、schema.sqlの破壊的DDL無し）は**全てPASS**。「要修正」の理由は上記6.の既存漏洩2件であり、Cycle 23実装そのものの欠陥ではない。

追加の任意提案として「`.env.example`のパスワードを空にすれば未編集起動を塞げる」との指摘があったが、P2指示書3.3が「コピー直後にCompose構文確認できるよう例示値を入れてもよい」と明示しているため、**P2仕様を優先して現状維持**とした。

### 観点B: Docker構成・配布物 — 総合判定「OK」（実バグ1件を検出、修正済み）

9項目中8項目PASS。**1件の実バグを検出したため修正した**:

- 指摘: `db`のhealthcheckが`CMD`(exec形式)なのに`$$MYSQL_USER`/`$$MYSQL_PASSWORD`を使用しており、変数が展開されずリテラル文字列が渡っていた。
- 対応: `CMD-SHELL`形式へ変更し、変数が正しく展開されることを`docker compose config`の解決結果で確認。修正後に再起動し、db healthy・全画面200・データ保持を再確認済み。
- **補足（正直な限界）**: `mysqladmin ping`はMySQLの仕様上、認証失敗でもサーバが生きていればexit 0を返す。コンテナ内で誤ったパスワードを与えて実測し、exit=0となることを確認した。したがってこのhealthcheckは「サーバ生存確認」であり「認証成功の確認」ではない。P2指示書3.2が`mysqladmin ping`を明示指定しているため実装はそれに従っているが、認証まで検証したい場合は`mysql -e "SELECT 1"`等への変更が必要である点をDexへ申し送る。

その他の任意指摘（`restart: unless-stopped`によりDocker Desktop起動時に自動起動する、appにhealthcheckが無い、QUICKSTARTのポート変更時の読み替え説明が無い等）は、P2仕様の範囲内または軽微なため今回は変更していない。

### 観点C: 禁止領域DIFF — 総合判定「OK」

- 変更が許可8ファイルに収まっていることを確認。
- 禁止領域（`src/main/java`、`mapper`、`*.xlsx`、`templates/`、`static/`）の差分は**ゼロ**。
- `schema.sql`の差分が先頭2行削除＋コメントのみで、テーブル・列・制約・初期マスタの業務構造が無変更であることを厳密確認。
- `application.properties`の差分が環境変数化・`continue-on-error`・`app.version`の3点に限定され、MyBatis/Thymeleaf等の既存業務設定が無変更であることを確認。
- **他AI/ユーザーの未コミット差分7ファイルと未追跡handoff文書50件超が、全て保全されている**ことを確認（`git stash`空、削除・巻き戻しの痕跡なし）。

申し送り事項として、環境変数必須化により`mvnw test`とDocker外のローカル起動がenv未設定で失敗する点が挙げられた（下記8.に記載）。

## 8. 通常起動への影響（重要）

`application.properties`からDB実値を除去し環境変数必須にしたため、**Dockerを使わない従来のローカル起動と`mvnw test`は、事前に環境変数を設定しないと起動に失敗する**。

- 必要な環境変数: `SPRING_DATASOURCE_URL` / `SPRING_DATASOURCE_USERNAME` / `SPRING_DATASOURCE_PASSWORD`
- これは「意図しないDBへ誤接続することを防ぐ」ためのfail-fast仕様であり、P2指示書3.5が承認済みの挙動。
- `DOCKER_QUICKSTART.md`末尾に変更点として明記した。
- 旧実パスワードをtracked fileへ戻して回避する対応は**行っていない**。

### `mvnw test`を実行していない理由

P2指示書5.4およびTake3の指示どおり、`mvnw test`は**実行していない**。既存の自動テストは通常のホストDBへ書き込む可能性があるため。今回の検証は`clean compile`＋Docker実機検証で行った。

## 9. 配布境界

- Docker Hub・その他registry・外部ストレージへのpush/uploadは**一切行っていない**（build/upはローカルのみ）。
- P4 OK前の本人へのフォルダ・image手渡しは**行っていない**。
- 本人以外へのコピーも行っていない。

## 10. 未実施項目と理由

| 項目 | 理由 |
|---|---|
| `mvnw test` | P2指示書の禁止事項（ホストDBへの書込みリスク）。意図的に未実施 |
| ダミー活動の保存・Excel出力の試行 | 要件書7項の受入確認6に含まれるが、P2指示書6.2は「ダミー保存を行う場合は」と条件付き記載。今回は名簿1件の登録でDB書込経路とvolume保持を確認するに留めた。Excel出力の実行はP4/Kazumax確認に委ねる |
| バックアップの別DB復元テスト | 要件書7項の受入確認9。P2指示書6.2の必須項目に含まれていないため未実施 |
| 6.の既存漏洩の修正 | Cycle 23の許可ファイル範囲外。CC独断禁止のためDex/Kazumax判断へ委ねる |

## 11. commit / push

（コミット後に追記）
