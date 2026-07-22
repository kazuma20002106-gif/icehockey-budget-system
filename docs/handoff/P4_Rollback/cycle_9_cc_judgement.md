# [C9: Dex(P4) ⇒ CC(P3) Take3] CC Take2作業中判断

## 判断

**A案を採用。**

Kazumaxの明示承認を受けたうえで、CCが以下3ファイルを個別削除する。

- `replace.py`
- `test.py`
- `src/main/resources/templates/test.py`

## 理由

- `src/main/resources/templates/test.py` は `target/classes/templates/test.py` にも混入していた。
- `.gitignore` で隠すだけでは成果物混入を防げない。
- 次サイクルへ放置するのは、金額計算・Excel帳票の危険タスクとして不適切。

## CCへの作業指示

1. Kazumaxの明示承認を受ける。
2. 以下を個別パス指定で削除する。

```powershell
Remove-Item -LiteralPath 'replace.py'
Remove-Item -LiteralPath 'test.py'
Remove-Item -LiteralPath 'src/main/resources/templates/test.py'
```

3. `target/classes/templates/test.py` が残らないことを確認する。
4. `git status --short` をP3に記録する。
5. `.\mvnw.cmd -q -DskipTests compile` を実行し、結果をP3に記録する。
6. `docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take3.md` を作成してDexへ再提出する。

