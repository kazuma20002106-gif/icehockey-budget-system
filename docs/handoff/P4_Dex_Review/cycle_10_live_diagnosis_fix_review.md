# [C10: Dex(P4) OK] 実機診断対応 小修正レビュー

作成日: 2026-06-24  
レビュアー: Dex  
対象:
- `docs/handoff/P4_Dex_Review/cycle_10_live_test_diagnosis.md`
- `docs/handoff/P3_CC_Report/cycle_10.md`
- `scripts/maestro_runner.ps1`
- `scripts/maestro_runner.tests.ps1`

---

## 1. レビュー結果

**OK（差し戻しなし）**

実機テストで発覚した `cc.done.json` の契約ズレに対して、プロンプト側の小修正が適切に入っています。  
`revision="revision_2"` や `result="sandbox_compliant"` の再発を防ぐため、数値revision・`result="success"` 固定・禁止例・完成JSONテンプレートが明記されました。

---

## 2. 確認内容

### 構文確認

```text
scripts/maestro_runner.ps1 parser OK
scripts/maestro_runner.tests.ps1 parser OK
```

### 外部通信なし統合テスト

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\maestro_runner.tests.ps1
結果: PASS=54  FAIL=0
```

### 差分確認

- `Invoke-ClaudeAgent` のプロンプトに `cc.done.json` の厳密契約が追加されています。
- `revision` はmanifest値と完全一致、数値のみと明記されています。
- `revision_2` / `r2` のような接頭辞付き文字列は禁止例として明記されています。
- `result` は `"success"` のみ許可と明記されています。
- `sandbox_compliant` / `ok` / `done` は禁止例として明記されています。
- `source_p1_sha256` はP1のSHA-256を事前計算してプロンプトへ埋め込む形になっています。
- P1ファイル不在時はPAUSEして止まるようになっています。
- H14で、実機異常を再現する `revision=2` のプロンプト契約検証が追加されています。

### 安全確認

- `git reset --hard` / `git restore .` / `git clean` の自動実行は見当たりません。
- 実Claude自動起動テストは実施されておらず、外部通信なしスタブのみです。
- 本番P1自動起動のStop Conditionsは維持されています。

---

## 3. Kazumax用チェック項目

次はまだ実行ボタン連打ではなく、Airが整理する手順に従って1ケースずつ確認してください。

1. 実行前に、Maestro Runnerのターミナルが古いPAUSE待ちで動き続けていないか確認する。
2. 成功系テストでは、ダミーP1を先に作り、その後manifestを置く。
3. `test_automation:r2` は処理済みなので、次回はrevisionを上げる。
4. 実行後、`cc.done.json` の `revision` が数値で、`result` が `"success"` になっていることを確認する。
5. 成功系が通ってから、禁止ファイルを触らせる失敗系テストに進む。
6. 失敗系では自動ロールバックされず、PAUSEで止まることを確認する。

---

## 4. 判断

この小修正はOKです。  
次はAirに、成功系と失敗系を分けた実機確認手順の整理を依頼してください。

---

## 5. ＋α提案

実機確認の手順書には、冒頭に「OneDriveの大量削除確認が出たら必ず保持を選ぶ」と明記した方が安全です。  
今回のような監視・隔離・テストファイル生成が絡む作業では、OneDriveの警告が出るだけで人間が迷いやすいためです。

TEAM_CHATにも本レビュー結果を追記してください。

