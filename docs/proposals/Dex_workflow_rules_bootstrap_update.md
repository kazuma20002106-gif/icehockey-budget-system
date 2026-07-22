# Dex提案 — 起動文にWORKFLOW_RULES.mdを追加する

## 提案

次担当への起動文を以下に更新する。

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。
```

## 理由

Airが `AGENTS.md` を圧縮し、詳細運用を `WORKFLOW_RULES.md` に分離したため。
新チャットで `AGENTS.md` と `CURRENT_STATUS.md` だけ読む運用だと、詳細な出口ゲートやHandoff Protocolを読み落とす可能性がある。

## 期待効果

チャット変更・コンテキスト圧縮・担当AI交代があっても、同じ運用ルールを復元しやすくなる。
