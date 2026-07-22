# PROJECT_RULES.md — budget-system 固有の危険領域と検証条件

このファイルは `AGENTS.md`（普遍的チームルール）の補足として、**このプロジェクト固有の危険領域・検証手順・リスク定義**を記載します。
他プロジェクトには持ち出さないこと。普遍的なルールは `AGENTS.md` と `docs/handoff/WORKFLOW_RULES.md` を参照してください。

> **重要（配置理由）**: このプロジェクト固有の強いルールは、`AGENTS.md` / `CLAUDE.md` / `.cursorrules` ではなく、必ずこのファイルに書きます。理由は、それら3ファイルが `マニュアル同期.ps1` によって `AI共通マニュアルテンプレ` から複数プロジェクトへ無条件上書き（`Copy-Item -Force`）で配布される共通テンプレートだからです。直接書き込んでも、同期が再実行されると跡形もなく消えます。`docs/PROJECT_RULES.md` は同期対象外なので、ここに書いた内容は同期の影響を受けません。（Cycle 10 Take2→Take3で実際にこの事故が発生したため明記しています。）

---

## 0. Air / CC / Dex の追加ルール（このプロジェクト固有）

### Air

- 新しい依頼を受けたら、設計や実装案を出す前に「タスク重要度・事前宣言」（タスク要約／危険度判定／理由／実行計画）を出すこと。
- Kazumaxが明示的に「承認」「進めて」と返すまで、コード編集をしないこと。
- 危険タスクは本ファイル「1. 危険ファイル・危険エリア一覧」を参照し、Air計画 → Dex事前レビュー → CC実装 → Dex事後レビューの完全プロセスを通すこと。

### CC

- コード変更時は `src/main/resources/application.properties` の `app.version` を更新すること。
- コード変更時は `.\mvnw.cmd -q -DskipTests compile` を実行し、`target/classes/application.properties` の `app.version` が同期していることを確認すること。
- コミットメッセージの先頭に `[vX.Y.Z]` を付けること。
- マニュアル・ドキュメントのみの変更（Javaコード・設定ファイル変更なし）ではバージョンアップ不要。
- P3報告書は `docs/handoff/P3_CC_to_Dex/` に保存すること。
- Kazumaxへのチャットは短くまとめ、次担当への合図文は必ず単独のコードブロックで出すこと。

### Dex

- P2は `docs/handoff/P2_Dex_to_CC/` に保存する。
- P4 OKは `docs/handoff/P4_Dex_Review/` に、P4 NGは `docs/handoff/P4_Rollback/` に保存する。
- 保存処理、DB、Excel出力、金額計算、参加者管理、日付計算を重点レビューする。
- P4 OK時のKazumax向け最終確認チェックリストは、P1要件を漏れなく含める。

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
- **resources配下の不要ファイル削除・混入対策を行ったサイクルでは、通常compileに加えて `.\mvnw.cmd clean compile`、または `target/` 削除後のcompileを実行すること。**

---

## 5. バージョン管理ルール（このプロジェクト固有）

- バージョンの管理場所: `src/main/resources/application.properties` の `app.version`
- コミット前に必ず `.\mvnw.cmd -q -DskipTests compile` を実行し、`target/classes/application.properties` のバージョンと一致を確認すること。
- コミットメッセージの先頭に `[vX.Y.Z]` を付けること。
- **ただし、マニュアル・ドキュメントのみの変更（Javaコード・設定ファイル変更なし）ではバージョンアップ不要。**

---

## 6. Kazumax代表からの絶対方針

> 「入力が簡単になっても、合算がうまくいってなかったらツールとしては全く意味がなく、正しくない書類を作るゴミツールになってしまう。全体の数値に関する部分は絶対に間違いがあってはならない。」
