# PROJECT_RULES.md — budget-system 固有の危険領域と検証条件

このファイルは `AGENTS.md`（普遍的チームルール）の補足として、**このプロジェクト固有の危険領域・検証手順・リスク定義**を記載します。
他プロジェクトには持ち出さないこと。普遍的なルールは `AGENTS.md` と `docs/handoff/WORKFLOW_RULES.md` を参照してください。

---

## 1. 危険ファイル・危険エリア一覧

以下のファイル・ディレクトリへの変更は、必ず **Air計画 → Dex事前レビュー → CC実装 → Dex事後レビュー** の完全プロセスを通すこと。

| ファイル / エリア | 危険理由 |
|---|---|
| `src/main/java/` 全体 | 実装変更はCC専任。他のAIが直接触れてはならない |
| `src/main/java/.../service/ExcelExportService.java` | Excel帳票・セル座標・金額合算を直接担うハイリスクファイル |
| `src/main/resources/mapper/*.xml` | DB I/Oに直結。誤変更で金額データが壊れる |
| `src/main/resources/schema.sql` | テーブル定義の変更は永続データに影響する |
| `src/main/resources/*.xlsx`（書類テンプレート） | 公式帳票フォーマット。セル座標がズレると全出力が壊れる |
| `src/main/resources/templates/` | ビルド時に `target/classes/templates/` へコピーされる。不要ファイルが混入しやすい |
| `src/main/resources/application.properties` | バージョン管理・DB接続先が記載されている |

---

## 2. 金額計算・Excel出力リスク

- 金額の合算ロジック（カテゴリ別・費目別）は「ツールとしての根幹」。**絶対に間違いが許されない。**
- セル座標は0-indexed（Apache POI形式）で管理する。テンプレートExcelと常に一致を確認すること。
- テンプレートに存在するダミー値（例：`830550` 等）は、出力前に必ずクリアすること。
- カテゴリ判定（成年男子／少年男子／成年女子／少年女子）の漏れは集計バグに直結する。
- `long` 型で集計し、`(int)` キャストせずに `cell.setCellValue((double)value)` で出力すること。

---

## 3. データベース・マッパーリスク

- `schema.sql` の変更はアプリ起動時に自動実行される。誤ったDDLはデータを破壊する。
- `mapper/*.xml` の誤変更は金額データの読み書きに即影響する。
- **DB変更はDexの事前レビュー必須。CCは単独で実行しないこと。**

---

## 4. テンプレートディレクトリの混入リスク

- `src/main/resources/templates/` 配下に検証スクリプト（`.py` 等）が混入すると、Mavenビルド時に `target/classes/templates/` へコピーされ、成果物に含まれる。
- コミット前に `git status` で未追跡ファイルを必ず確認すること。

---

## 5. バージョン管理ルール（このプロジェクト固有）

- バージョンの管理場所: `src/main/resources/application.properties` の `app.version`
- コミット前に必ず `.\mvnw.cmd -q -DskipTests compile` を実行し、`target/classes/application.properties` のバージョンと一致を確認すること。
- コミットメッセージの先頭に `[vX.Y.Z]` を付けること。
- **ただし、マニュアル・ドキュメントのみの変更（Javaコード・設定ファイル変更なし）ではバージョンアップ不要。**

---

## 6. Maven Wrapperの既知問題（Dex環境）

Dex（Cursor等）の環境では以下のエラーが発生し、コンパイル実行が不可能な場合がある。

```
Cannot index into a null array.
Cannot start maven from wrapper
```

この場合はCC（またはKazumaxが手動で）`.\mvnw.cmd -q -DskipTests compile` を実行し、結果をP3報告書に記録すること。

---

## 7. Kazumax代表からの絶対方針

> 「入力が簡単になっても、合算がうまくいってなかったらツールとしては全く意味がなく、正しくない書類を作るゴミツールになってしまう。全体の数値に関する部分は絶対に間違いがあってはならない。」
