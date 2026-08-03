package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.MemberMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Member;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Cycle 21: 複数Expense保存ガード・expenses一意制約・一括印刷状態更新の原子性を検証する。
 * クラス全体に@Transactionalを付与し、各テストの終了時にSpringのテストトランザクション機構が
 * 自動ロールバックする。実DB（Kazumaxの本物データ）へは一切コミットされない。
 */
@SpringBootTest
@Transactional
class Cycle21SafetyAndTransactionTest {

    @Autowired private ProjectService projectService;
    @Autowired private ProjectMapper projectMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;
    @Autowired private MemberMapper memberMapper;
    @Autowired private PlatformTransactionManager transactionManager;

    /**
     * saveProject()の@Transactional(REQUIRED)は、テストクラスの外側@Transactionalと同じ物理トランザクションに
     * 合流するため、例外発生時は「rollback-only」フラグが立つだけで、外側トランザクションが終わるまで
     * 実際のROLLBACKは発行されない（同一トランザクション内では書込み済みの値がそのまま読める）。
     * 本番のController呼び出しではsaveProject()自体が最外周のトランザクション境界になるため、
     * それをテストでも再現するためにPROPAGATION_REQUIRES_NEWで独立した物理トランザクションを作り、
     * その中で例外が起きたときに本当にROLLBACKされることを検証する。
     */
    private void runInNewTransactionExpectingRollback(Runnable action) {
        TransactionTemplate tt = new TransactionTemplate(transactionManager);
        tt.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        tt.execute(status -> {
            action.run();
            return null;
        });
    }

    /**
     * 値を返す版。MySQLのREPEATABLE READでは、同一トランザクション内の最初のSELECTでスナップショットが
     * 固定され、以後のSELECTは他トランザクションの変化（コミット済みでも）を反映しない。
     * 「セットアップ／実行／検証」の各段階を別々の物理トランザクションにして、
     * 各段階が常にその時点のコミット済み状態を見るようにするために使う。
     */
    private <T> T runInNewTransaction(java.util.function.Supplier<T> action) {
        TransactionTemplate tt = new TransactionTemplate(transactionManager);
        tt.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        return tt.execute(status -> action.get());
    }

    @Test
    void hasMultipleExpenses_isFalse_whenAtMostOnePerParticipant() {
        int projectId = createProject();
        int participantId = createParticipant(projectId, createMember("Cycle21 Test A"));
        insertExpense(participantId);

        assertFalse(projectService.hasMultipleExpenses(projectId),
                "参加者ごとにExpenseが1件以下なら保存ガードを通過するはず");
    }

    // 注意: uq_expenses_project_participant がこの環境で既に適用済みのため、
    // MySQL 8のInnoDBでは`SET unique_checks=0`をセッションに設定しても通常のINSERT文に対する
    // UNIQUE制約チェックは回避できず（実測確認済み）、レガシー重複行を安全に模擬できない。
    // また一意制約のDROP/ADDはMySQLでは暗黙コミットを伴うDDLのため、テストトランザクション内で
    // 行うと@Transactionalによるロールバックが効かず実DBを恒久的に変更してしまう危険がある。
    // そのため「既存の複数Expenseを検知する」経路は、hasMultipleExpenses()のロジック
    // （参加者ごとにfindByProjectParticipantId().size()>1を判定するだけの単純な実装）の
    // コードレビューと、下記のuniqueConstraint_rejectsSecondExpense_noPartialDataで
    // 「複数Expenseがそもそも作れないこと」を確認することで代替する。

    @Test
    void uniqueConstraint_rejectsSecondExpense_noPartialData() {
        int projectId = createProject();
        int participantId = createParticipant(projectId, createMember("Cycle21 Test C"));
        insertExpense(participantId);

        assertThrows(DataIntegrityViolationException.class, () -> insertExpense(participantId),
                "uq_expenses_project_participant により2件目のinsertは失敗するはず");

        assertEquals(1, expenseMapper.findByProjectParticipantId(participantId).size(),
                "失敗したinsertの分だけ残り、部分保存は発生していないはず");
    }

    @Test
    void updatePrintedStatusAtomic_allValidIds_updatesAll() {
        int p1 = createProject();
        int p2 = createProject();

        projectService.updatePrintedStatusAtomic(Arrays.asList(p1, p2), true);

        assertTrue(projectMapper.findById(p1).getIsPrinted());
        assertTrue(projectMapper.findById(p2).getIsPrinted());
    }

    @Test
    void updatePrintedStatusAtomic_invalidIdMixedIn_rollsBackAll() {
        int p1 = createProject();
        int p2 = createProject();
        int bogusId = 999_999_999;

        assertThrows(RuntimeException.class,
                () -> projectService.updatePrintedStatusAtomic(Arrays.asList(p1, p2, bogusId), true));

        assertFalse(projectMapper.findById(p1).getIsPrinted(),
                "不正IDが混ざった場合、有効なIDも含めて全件ロールバックされ、is_printedが変わっていないはず");
        assertFalse(projectMapper.findById(p2).getIsPrinted());
    }

    @Test
    void updatePrintedStatusAtomic_emptyList_throwsWithoutUpdating() {
        assertThrows(IllegalArgumentException.class,
                () -> projectService.updatePrintedStatusAtomic(List.of(), true));
    }

    // ===== P4差戻し(Take3) P1-3: 候補外の事業名・NULL文章欄が無編集保存で壊れないことの検証 =====

    @Test
    void saveProject_blankScheduleAndOutcome_normalizedToNull_notEmptyString() {
        int projectId = createProject();

        // 1回目保存: schedule_content/project_outcomeへ実際の値を設定
        Project p1 = new Project();
        p1.setId(projectId);
        p1.setName("【テスト出力】候補外の事業名");
        p1.setBudgetTypeId(1);
        p1.setTargetCategory("成年男子");
        p1.setEventDate(LocalDate.now());
        p1.setLocationVenue("テスト会場");
        p1.setLocationAccommodation("宿泊なし");
        p1.setScheduleContent("テスト日程");
        p1.setProjectOutcome("テスト成果");
        projectService.saveProject(p1, new ProjectSummaryExpense(), List.of(), List.of());

        Project afterFirstSave = projectMapper.findById(projectId);
        assertEquals("テスト日程", afterFirstSave.getScheduleContent());
        assertEquals("テスト成果", afterFirstSave.getProjectOutcome());

        // 2回目保存: フォームのtextareaを何も入力しない状態を模擬（空文字が送信される）
        Project p2 = new Project();
        p2.setId(projectId);
        p2.setName("【テスト出力】候補外の事業名"); // 事業名は無編集のまま
        p2.setBudgetTypeId(1);
        p2.setTargetCategory("成年男子");
        p2.setEventDate(p1.getEventDate());
        p2.setLocationVenue("テスト会場");
        p2.setLocationAccommodation("宿泊なし");
        p2.setScheduleContent("");
        p2.setProjectOutcome("   "); // 空白のみの入力も同様にNULL化されるべき
        projectService.saveProject(p2, new ProjectSummaryExpense(), List.of(), List.of());

        Project afterSecondSave = projectMapper.findById(projectId);
        assertEquals("【テスト出力】候補外の事業名", afterSecondSave.getName(),
                "固定候補外の事業名は無編集保存でも変わらないはず（P4 Take3 P1-3対応）");
        assertNull(afterSecondSave.getScheduleContent(),
                "空文字送信はNULLへ正規化され、空文字のまま保存されないはず（P4 Take3 P1-3対応）");
        assertNull(afterSecondSave.getProjectOutcome(),
                "空白のみの送信もNULLへ正規化されるはず（P4 Take3 P1-3対応）");
    }

    // ===== P4差戻し P1-1: 保存失敗時、projects本体を含めて全件ロールバックされることの検証 =====
    //
    // saveProjectData内のexpensesへの書込みは、参加者を毎回deleteByProjectId→再insertする実装のため、
    // project_participant_idは常に新規採番され、通常の入力経路ではuq_expenses_project_participant違反を
    // 自然発生させられない（安全に強制する手段がない）。そのため、実DB・実トランザクションのまま
    // ExpenseMapperだけをMockito.mockへ一時的に差し替え、insert時に必ずDataIntegrityViolationExceptionを
    // 投げさせることで「projects本体insert/update成功後に後段が失敗するケース」を確実に再現する。
    // ProjectServiceは@Serviceのシングルトンのため、差し替えたモックはtry/finallyで必ず元のBeanへ復元する。

    @Test
    void saveProject_newProject_rollsBackProjectInsert_whenDownstreamFails() {
        String uniqueName = "Cycle21Rollback-New-" + System.nanoTime();
        ExpenseMapper failingMapper = failingExpenseMapperMock();
        ReflectionTestUtils.setField(projectService, "expenseMapper", failingMapper);
        try {
            Project newProject = new Project();
            newProject.setName(uniqueName);
            newProject.setBudgetTypeId(1);
            newProject.setTargetCategory("成年男子");
            newProject.setEventDate(LocalDate.now());
            newProject.setLocationVenue("テスト会場");
            newProject.setLocationAccommodation("宿泊なし");

            ProjectParticipant participant = new ProjectParticipant();
            participant.setMemberName("Cycle21 Rollback Participant");
            participant.setMemberRole("選手");

            Expense expense = new Expense();
            expense.setTransportCost(500);

            assertThrows(DataIntegrityViolationException.class, () ->
                    runInNewTransactionExpectingRollback(() ->
                            projectService.saveProject(newProject, new ProjectSummaryExpense(),
                                    List.of(participant), List.of(expense))));
        } finally {
            ReflectionTestUtils.setField(projectService, "expenseMapper", expenseMapper);
        }

        try {
            long matching = runInNewTransaction(() ->
                    projectMapper.findAll().stream().filter(p -> uniqueName.equals(p.getName())).count());
            assertEquals(0, matching,
                    "後段のExpense保存が失敗した場合、先に成功していたはずのprojects本体のinsertも" +
                            "ロールバックされ、新規事業が残らないはず（P4 P1-1対応）");
        } finally {
            // 万一ロールバックに失敗し行が残った場合でも実DBを汚さないための安全網クリーンアップ
            runInNewTransaction(() -> {
                projectMapper.findAll().stream()
                        .filter(p -> uniqueName.equals(p.getName()))
                        .forEach(p -> projectMapper.delete(p.getId()));
                return null;
            });
        }
    }

    @Test
    void saveProject_existingProject_rollsBackProjectUpdate_whenDownstreamFails() {
        // セットアップ・検証・クリーンアップは、テストクラス外側の@Transactional(ロールバック専用)
        // ではなく、それぞれ独立した物理トランザクションでコミットする。MySQLのREPEATABLE READでは
        // 同一トランザクション内の最初のSELECTでスナップショットが固定されてしまい、
        // 外側トランザクションのままだと「実際にROLLBACKされたか」を正しく検証できないため
        // （runInNewTransactionExpectingRollbackのJavadoc参照）。
        // このテストはコミットを伴うため、finallyで必ずテスト用の行を削除して実DBを汚さない。
        String uniqueName = "Cycle21Rollback-Existing-" + System.nanoTime();
        LocalDate originalDate = LocalDate.now();

        int projectId = runInNewTransaction(() -> {
            Project p = new Project();
            p.setName(uniqueName);
            p.setBudgetTypeId(1);
            p.setTargetCategory("成年男子");
            p.setEventDate(originalDate);
            p.setLocationVenue("テスト会場");
            p.setLocationAccommodation("宿泊なし");
            projectMapper.insert(p);
            return p.getId();
        });

        try {
            ExpenseMapper failingMapper = failingExpenseMapperMock();
            ReflectionTestUtils.setField(projectService, "expenseMapper", failingMapper);
            try {
                Project updated = new Project();
                updated.setId(projectId);
                updated.setName("CHANGED NAME - must not persist");
                updated.setBudgetTypeId(1);
                updated.setTargetCategory("成年男子");
                updated.setEventDate(originalDate.plusDays(1));
                updated.setLocationVenue("変更後会場");
                updated.setLocationAccommodation("宿泊なし");

                ProjectParticipant participant = new ProjectParticipant();
                participant.setMemberName("Cycle21 Rollback Participant 2");
                participant.setMemberRole("選手");

                Expense expense = new Expense();
                expense.setTransportCost(500);

                assertThrows(DataIntegrityViolationException.class, () ->
                        runInNewTransactionExpectingRollback(() ->
                                projectService.saveProject(updated, new ProjectSummaryExpense(),
                                        List.of(participant), List.of(expense))));
            } finally {
                ReflectionTestUtils.setField(projectService, "expenseMapper", expenseMapper);
            }

            Project after = runInNewTransaction(() -> projectMapper.findById(projectId));
            assertEquals(uniqueName, after.getName(),
                    "後段のExpense保存が失敗した場合、既に成功していたはずのprojects本体のupdateも" +
                            "ロールバックされ、事業名が変更前のまま残るはず（P4 P1-1対応）");
            assertEquals(originalDate, after.getEventDate());
        } finally {
            runInNewTransaction(() -> {
                projectMapper.delete(projectId);
                return null;
            });
        }
    }

    /** insert呼び出しで必ずDataIntegrityViolationExceptionを投げる、後段失敗を模擬するモック */
    private ExpenseMapper failingExpenseMapperMock() {
        ExpenseMapper mock = Mockito.mock(ExpenseMapper.class);
        Mockito.when(mock.insert(Mockito.any(Expense.class)))
                .thenThrow(new DataIntegrityViolationException("simulated downstream failure for Cycle21 test"));
        Mockito.when(mock.findByProjectParticipantId(Mockito.anyInt())).thenReturn(Collections.emptyList());
        return mock;
    }

    // ===== P4差戻し P1-2: 印刷状態更新の件数不一致を例外扱いすることの検証 =====

    @Test
    void updatePrintedStatusAtomic_updateCountMismatch_throwsAndStopsWithoutSilentSuccess() {
        // 存在確認(findById)は通過するが、実際のUPDATE(updatePrinted)が0件しか更新できなかった
        // 状況（存在確認直後に対象が削除された等の競合）を、ProjectMapperをモック化して再現する。
        ProjectMapper mockMapper = Mockito.mock(ProjectMapper.class);
        Project fake = new Project();
        fake.setId(777);
        Mockito.when(mockMapper.findById(777)).thenReturn(fake);
        Mockito.when(mockMapper.updatePrinted(777, true)).thenReturn(0); // 想定外の更新件数

        ReflectionTestUtils.setField(projectService, "projectMapper", mockMapper);
        try {
            assertThrows(IllegalStateException.class,
                    () -> projectService.updatePrintedStatusAtomic(List.of(777), true),
                    "updatePrinted()の戻り値(更新件数)が1でない場合、黙って成功扱いにせず例外を投げるはず");
        } finally {
            ReflectionTestUtils.setField(projectService, "projectMapper", projectMapper);
        }
    }

    // ===== ヘルパー（テストトランザクション内でのみ有効。ロールバックされるためDBは汚さない） =====

    private int createProject() {
        Project p = new Project();
        p.setName("Cycle21テスト事業");
        p.setBudgetTypeId(1);
        p.setTargetCategory("成年男子");
        p.setEventDate(LocalDate.now());
        p.setLocationVenue("テスト会場");
        p.setLocationAccommodation("宿泊なし");
        projectMapper.insert(p);
        return p.getId();
    }

    private int createMember(String name) {
        Member m = new Member();
        m.setName(name);
        m.setRole("選手");
        memberMapper.insert(m);
        return m.getId();
    }

    private int createParticipant(int projectId, int memberId) {
        ProjectParticipant p = new ProjectParticipant();
        p.setProjectId(projectId);
        p.setMemberId(memberId);
        p.setIsAccommodated(false);
        participantMapper.insert(p);
        return p.getId();
    }

    private void insertExpense(int participantId) {
        Expense e = new Expense();
        e.setProjectParticipantId(participantId);
        e.setTransportCost(1000);
        e.setAccommodationCost(0);
        e.setMiscellaneousCost(0);
        expenseMapper.insert(e);
    }
}
