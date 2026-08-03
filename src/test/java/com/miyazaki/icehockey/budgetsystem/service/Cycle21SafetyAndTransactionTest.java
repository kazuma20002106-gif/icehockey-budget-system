package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.MemberMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Member;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Arrays;
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
