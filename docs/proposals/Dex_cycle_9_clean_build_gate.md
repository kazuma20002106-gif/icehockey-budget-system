# Dex Plus Alpha Proposal: Clean Build Gate

## Proposal

危険タスクで `src/main/resources/` 配下の混入ファイルを削除した場合、最終確認では通常の `compile` だけでなく、少なくとも一度は `clean compile` または `target/` 削除後のcompileを行う。

## Reason

今回、ソース側の `src/main/resources/templates/test.py` は削除済みだったが、Dex環境の `target/classes/templates/test.py` には古い成果物が残っていた。

`target/` はgit管理外のためコミット混入リスクはないが、通常の `compile` は古い `target/classes` 内の不要ファイルを必ず消すとは限らない。
配布物やローカル確認の衛生状態を安定させるには、resources混入を扱ったサイクルだけでもclean buildを出口条件にした方が安全。

## Suggested Rule

`docs/PROJECT_RULES.md` のMaven/検証項目に以下を追記する。

```text
resources配下の不要ファイル削除・混入対策を行ったサイクルでは、通常compileに加えて `.\mvnw.cmd clean compile`、または `target/` 削除後のcompileを実行する。
Dex環境でMaven Wrapperが起動できない場合は、CCまたはKazumaxが実行結果をP3に記録する。
```
