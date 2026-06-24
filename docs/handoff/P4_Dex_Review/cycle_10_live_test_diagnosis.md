# [C10: Dex診断] Phase 2 実機テスト異常の原因整理と復旧方針

作成日: 2026-06-24  
担当: Dex  
対象:
- `docs/handoff/maestro/maestro.log`
- `docs/handoff/maestro/processed.log`
- `docs/handoff/CURRENT_STATUS.md`
- `scripts/maestro_runner.ps1`

---

## 1. 結論

今回の異常は、主に **実機テスト用プロンプト・ファイル配置・完了JSON契約の不整合** が原因です。

Maestro Runnerの安全装置は正しく働いており、`done.json` の仕様違反を検知してPAUSEしました。  
ただし、実Claudeに渡すプロンプトがまだ曖昧で、CCが `cc.done.json` に以下のような不正値を書いたため、正常完了扱いになりませんでした。

```text
done.json.revision 不一致: 'revision_2' vs manifest '2'
done.json.result が許可値ではありません: 'sandbox_compliant'
```

---

## 2. 観測事実

### 2.1 `test_automation r2` は検証済み扱い

`processed.log` には以下が残っています。

```text
test_automation:r2|validated at=2026-06-24T13:42:08.7006463+09:00
```

このため、同じ `cycle=test_automation` / `revision=2` のmanifestを再投入しても、処理済みとしてスキップされる可能性があります。  
再テストする場合は、revisionを上げるのが安全です。

### 2.2 `cc.done.json` とP3は現在残っていない

ワークスペース全体で `cc.done.json` を検索しましたが、現時点では残存ファイルは見つかりませんでした。  
`docs/handoff/P3_CC_Report/test_automation.md` も見つかりませんでした。

ただし、`maestro.log` には不一致検知の記録が残っているため、原因把握には十分です。

### 2.3 `dummy_success` / `dummy_fail` はP1不足で隔離

以下のmanifestは複数回隔離されています。

```text
dummy_success.ready.json
dummy_fail.ready.json
```

理由:

```text
P1が存在しないかディレクトリです:
docs/handoff/P1_Air_Blueprint/dummy_success.md
docs/handoff/P1_Air_Blueprint/dummy_fail.md
```

つまり、manifestだけ先に投入され、対応するP1ファイルが存在しなかった状態です。

---

## 3. 原因分類

### 原因A: 自動起動CCへの `cc.done.json` 契約がまだ弱い

現在のプロンプトは `p3_file` と `p3_sha256` については明記していますが、以下が弱いです。

- `revision` は数値またはmanifestと同じ値 `2` にすること。
- `revision_2` のような文字列は禁止。
- `result` は必ず `"success"` にすること。
- `"sandbox_compliant"` 等の独自値は禁止。

そのため、実Claudeが自然言語的に「revision_2」「sandbox_compliant」と書いてしまいました。

### 原因B: ダミーP1とmanifestの作成順序が崩れている

`dummy_success.md` / `dummy_fail.md` が存在しないままmanifestが投入され、隔離されています。

Phase 2の実機テストでは、順序は必ず以下です。

1. P1ファイルを作成する。
2. P1のSHA-256を計算する。
3. そのSHA-256を含むmanifestを作成する。
4. manifestを最後に `.ready.json` として配置する。

---

## 4. 復旧方針

### 4.1 今すぐやるべきこと

1. 現在起動中のMaestro Runnerがあれば、いったん `Ctrl + C` で止める。
2. `PAUSE` が残っていないか確認する。
3. すでに隔離された `dummy_success` / `dummy_fail` のmanifestは再利用しない。
4. 次回は新しいrevisionでやり直す。

### 4.2 CCに依頼する小修正

`scripts/maestro_runner.ps1` の `Invoke-ClaudeAgent` 内プロンプトを強化してください。

最低限、`cc.done.json` について以下を明記する必要があります。

```text
cc.done.json は必ず以下の値にすること:
- cycle: manifestのcycleと完全一致
- revision: manifestのrevisionと完全一致。今回なら 2。`revision_2` のような文字列は禁止。
- result: 必ず "success"。`sandbox_compliant` などは禁止。
```

可能なら、完成JSONテンプレートをプロンプト内に入れるのが安全です。

### 4.3 Airに依頼する手順修正

Airの実機確認手順は、以下の2本に分けるべきです。

1. 成功系: `dummy_success_rN`
   - P1とmanifestを正しい順序で作る。
   - P3とdone.jsonだけを作らせる。
   - `result="success"` を厳守させる。

2. 失敗系: `dummy_fail_rN`
   - 成功系が通った後に実施する。
   - わざと許可外ファイルを作らせ、PAUSEすることを確認する。

---

## 5. 次回実行時の注意

- `test_automation:r2` はprocessed済みなので、同じrevisionを使わない。
- `dummy_success.md` / `dummy_fail.md` が存在しない状態でmanifestを投げない。
- `cc.done.json` の `revision` と `result` は厳密一致が必要。
- 実Claude自動起動は課金・利用制限・PAUSEを伴うため、Kazumax承認後に1ケースずつ実行する。

---

## 6. Dex判断

今回はMaestro Runnerの安全装置が役割を果たした異常系です。  
コード本体の大規模修正ではなく、まずは **CCによるプロンプト契約の小修正** と **Airによる実機手順の整理** が最適です。

