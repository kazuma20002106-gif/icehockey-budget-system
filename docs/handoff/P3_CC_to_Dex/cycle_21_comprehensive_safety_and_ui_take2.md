[C21: CC(P3) Take2 ⇒ Dex(P4)]

# Cycle 21 Take2 CC実装報告（P1-1/P1-2修正 + インシデント対応）

## 1. 対象と範囲

Dex(P4)差し戻し（`docs/handoff/P4_Dex_Review/cycle_21_comprehensive_safety_and_ui.md`）のP1-1/P1-2のみを修正した。金額計算・Excel・出力URL・雑費関連は無変更。

## 2. P1-1修正: 保存失敗時にprojects本体が部分保存される問題

### 修正前の問題

`ActivityController.save()`が`projectMapper.insert/update`を`ProjectService.saveProjectData`の`@Transactional`より先に（別トランザクションで）実行していたため、後段で`DataIntegrityViolationException`が発生した場合、事業本体（projects）だけがコミット済みのまま残り得た。

### 修正内容

- `ProjectService.saveProject(Project, ProjectSummaryExpense, List<ProjectParticipant>, List<Expense>)`を新設（`@Transactional`）。
  - 既存活動のガード確認（`hasMultipleExpenses`）→ `projectMapper.insert/update` → `saveProjectData`（参加者・Expense再作成）を**1つのメソッド・1トランザクション**にまとめた。
  - ガード検知時は新設の`MultiExpenseGuardException`をthrow。
- `ActivityController.save()`は`projectMapper.insert/update`を直接呼ばなくなり、`projectService.saveProject(...)`の呼び出し1本に統一。
- 例外は`MultiExpenseGuardException`→`error=multi_expense_guard`、`DataIntegrityViolationException`→`error=save_integrity_violation`へ振り分け。

### 検証方法と結果

通常の入力経路では、`saveProjectData`が参加者を毎回`deleteByProjectId`→再insertする実装のため、`project_participant_id`は常に新規採番され、`uq_expenses_project_participant`違反を自然発生させられない。そこで`ExpenseMapper`をMockitoで一時的にモック化し、`insert()`で必ず`DataIntegrityViolationException`を投げさせ、「projects本体のinsert/update成功後に後段が失敗するケース」を確実に再現した（`ProjectService`はシングルトンBeanのため、モックはtry/finallyで必ず実Beanへ復元）。

自動テストで以下を確認（`Cycle21SafetyAndTransactionTest`、DB操作は原則テストトランザクションでロールバックし実DBを汚さない）:

- `saveProject_newProject_rollsBackProjectInsert_whenDownstreamFails`: 新規事業で後段が失敗した場合、`projects`のinsertも含めて全件ロールバックされ、新規事業が残らないことを確認。
- `saveProject_existingProject_rollsBackProjectUpdate_whenDownstreamFails`: 既存事業で後段が失敗した場合、`projects`のupdateもロールバックされ、事業名・活動日が変更前のまま残ることを確認。

**テスト実装上の注記**: この2テストは、`saveProject()`の`@Transactional(REQUIRED)`がテストクラス外側の`@Transactional`と同一の物理トランザクションに合流してしまうと、例外発生時に「rollback-only」フラグが立つだけで実際のROLLBACKが即時発行されず、検証にならないという問題があった。そのため`PlatformTransactionManager`＋`TransactionTemplate`で`PROPAGATION_REQUIRES_NEW`の独立した物理トランザクションを作り、本番のController呼び出し（`saveProject()`自体が最外周のトランザクション境界になる）と同じ条件を再現した。この2テストはセットアップ・実行・検証を別々の物理トランザクションで実際にコミット/ロールバックするため、finallyで必ずテスト用データを削除するクリーンアップを行っている。

## 3. P1-2修正: 印刷状態更新で更新件数0を失敗扱いにしていない問題

### 修正内容

`ProjectService.updatePrintedStatusAtomic()`内の更新ループで、`projectMapper.updatePrinted(id, isPrinted)`の戻り値（更新件数）を検査し、`1`以外なら`IllegalStateException`をthrowするよう変更。`@Transactional`により、それまでの更新も含めて全件ロールバックされる。

### 検証方法と結果

`updatePrintedStatusAtomic_updateCountMismatch_throwsAndStopsWithoutSilentSuccess`（新規テスト）: `ProjectMapper`をMockitoでモック化し、`findById`は存在確認を通すが`updatePrinted`が0件を返す状況（存在確認直後に対象が削除された等の競合を模擬）を再現し、`IllegalStateException`がthrowされることを確認。

## 4. 自動テスト結果

```
.\mvnw.cmd -q test
```
`BudgetSystemApplicationTests`(1) + `Cycle21SafetyAndTransactionTest`(11) + `ExcelExportServiceTest`(2) = **14件、失敗・エラー0件**。

```
.\mvnw.cmd -q -DskipTests compile
grep -n "app.version" src/main/resources/application.properties target/classes/application.properties
```
コンパイル成功。`app.version`はsrc/targetともに`v2.6.1`で一致。

## 5. インシデント: 実機確認中のactivity id=1データ破壊と復旧

Take2の実機スモークテスト中、CC(P3)がブラウザで本物活動`id=1`の編集フォームを内容確認せずに再送信し、`name`（プルダウンが実際の値`【テスト出力】強化練習`に一致せず未選択表示だった）が空文字に、`schedule_content`/`project_outcome`も意図せず変化する事故を起こした。詳細・原因・復旧の全経緯は`docs/handoff/INCIDENT_cycle21_take2_project1_data_loss.md`に記録済み。

- Kazumaxへ即時報告し、Dexへセカンドオピニオンを依頼（`docs/handoff/P4_Dex_Review/incident_cycle21_take2_project1_recovery_second_opinion.md`）。
- Dexが提示した条件付き復旧SQL（`WHERE id=1 AND name='' AND schedule_content='' AND project_outcome='技術力・チーム連携の向上'`）を、Kazumaxの明示承認後に1回だけ実行。
- 実行前にSELECTで現在値がDexの想定AFTER値と一致することを確認済み。実行後のSELECT照合で、`name='【テスト出力】強化練習'`、`schedule_content=NULL`、`project_outcome=NULL`へ復元され、他の列（budget_type_id/target_category/event_date/location_venue/location_accommodation/accommodation_nights/is_printed）は不変であることを確認。WHERE条件がPRIMARY KEY＋事故直後の3列値と完全一致する設計のため、更新件数は0件または1件のみ可能であり、値が復元されたことから**更新件数1件**と結論した。
- 関連テーブル（`project_participants`=2件、`expenses`=2件、`project_summary_expenses`=1件、いずれもproject_id=1）と他プロジェクトの`is_printed`状態（id10=1, id22=1, 他=0、`projects`総数9件）に影響がないことを確認。

**再発防止**: 本物活動の編集フォームを内容確認せずに送信するテスト手法を今後禁止する。保存系の実機確認は原則テスト専用の新規活動（作成→検証→削除）で行い、本物活動に例外的に触れる場合は送信前に対象行の全列を読取バックアップしてから行う。

## 6. CCクルー利用

**不使用**。今回はDex差し戻しのP1-1/P1-2という狙いの明確な2点修正であり、変更範囲・観点が狭く単独確認で十分と判断した。加えて実機確認中に発生したインシデント対応にリソースを割いたため、範囲を絞った。

## 7. compile/version

```
app.version: src/main/resources/application.properties = v2.6.1
             target/classes/application.properties     = v2.6.1
```
同期確認済み。

## 8. 未実施の実機確認

- インシデントにより、通常の活動保存（新規/編集）フローのHTTP/ブラウザでの実機確認は、本物データに対しては実施していない。上記4章の自動テスト（実DB・実トランザクションを用いたMockito差し替え方式）で、P1-1/P1-2の契約は十分に検証済みと判断する。
- 印刷状態更新の実機確認（1件のみ変更→復元、不正ID混在時のロールバック）はCycle 21 Take1で実施済みであり、P1-2の修正はその後段の検査を追加しただけで通常経路の動作を変えていないため、Take2で再実施していない。

## 9. commit / push

commit hash: `11de2e4`（`[v2.6.1] Cycle 21 Take2: P1-1/P1-2修正 + activity id=1データ復旧`）。origin/mainへpush済み（6074130→11de2e4）。

## 10. 最終git status

Cycle 21 Take2対象ファイル（`ActivityController.java`, `ProjectService.java`, `MultiExpenseGuardException.java`（新規）, `Cycle21SafetyAndTransactionTest.java`, `application.properties`, `docs/handoff/INCIDENT_cycle21_take2_project1_data_loss.md`（更新）, 本報告書, `docs/handoff/CURRENT_STATUS.md`）のみをstage・commitする。Take2対象外の差分（`.cursorrules`等の共通マニュアル、他AIのhandoff/proposals、`.claude/launch.json`、`tmp/`）には一切触れていない。
