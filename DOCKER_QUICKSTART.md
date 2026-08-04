# Docker クイックスタート（ローカル試運転版）

> **このバージョンは「ローカル試運転版」です。**
> 外部への共有・インターネット公開・Docker Hub等への登録はしないでください。
> 本物の活動データを入れる前提の環境ではありません。

---

## 1. Docker が使えるか確認する

Docker Desktop を起動してから、次を実行します。

```bash
docker version
```

`Client` と `Server` の両方が表示されればOKです。`Server` が出ない場合は Docker Desktop がまだ起動中です。

```bash
docker compose version
```

## 2. 設定ファイルを用意する（初回だけ）

```bash
copy .env.example .env
```

作成した `.env` を開き、**パスワード2つ（`MYSQL_PASSWORD` と `MYSQL_ROOT_PASSWORD`）を自分で決めた値に変更**してください。
この2つは Docker 内の試運転用DB専用です。ホストPCの本物のMySQLのパスワードは書かないでください。

`.env` はGit管理外です。

## 3. 設定に誤りがないか確認する

```bash
docker compose config --quiet
```

何も表示されなければOKです。エラーが出る場合は `.env` の記入漏れです。

## 4. 起動する

```bash
docker compose up -d --build --wait
```

## 5. ブラウザで開く

```
http://localhost:18080
```

## 6. ログを見る

```bash
docker compose logs --tail 200 app db
```

## 7. 停止する（データは残ります）

```bash
docker compose down
```

DBのデータは名前付きvolume（`budget-pilot-db-data`）に保存されているため、停止・再起動しても消えません。

## 8. プログラムを更新したとき

```bash
docker compose up -d --build --wait
```

イメージだけが差し替わり、DBのデータはそのまま保持されます。

---

## データについての注意

- **名前付きvolumeは「永続化」であって「バックアップ」ではありません。** volumeを削除すればデータも消えます。大事な記録は別途控えを取ってください。
- `docker compose down -v` はvolumeごと削除する操作です。**通常の停止では使わないでください。** データを意図的に全消しする場合だけ使います。

## 通常のローカル起動（Dockerを使わない場合）の変更点

Cycle 23 から、DB接続情報は `application.properties` に直接書かず、**環境変数で渡す方式**に変わりました。

そのため、Dockerを使わずに `mvnw spring-boot:run` などで起動する場合は、事前に次の3つの環境変数を設定する必要があります。設定がないと起動に失敗します（誤って意図しないDBへ接続することを防ぐための仕様です）。

- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`

Docker で起動する場合は `compose.yaml` が自動で渡すため、この設定は不要です。
