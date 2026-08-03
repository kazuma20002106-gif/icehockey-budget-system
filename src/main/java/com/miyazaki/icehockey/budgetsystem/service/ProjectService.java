package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.MemberMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Member;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ProjectService {

    @Autowired
    private ProjectMapper projectMapper;

    @Autowired
    private ProjectParticipantMapper participantMapper;

    @Autowired
    private ExpenseMapper expenseMapper;

    @Autowired
    private ProjectSummaryExpenseMapper summaryExpenseMapper;

    @Autowired
    private MemberMapper memberMapper;

    /**
     * 対象活動の参加者のうち、1人でもExpenseが2件以上あればtrueを返す（Cycle 21）。
     * 「1参加者・1事業 = 1精算集約行」の前提が崩れている状態を検出し、
     * 編集画面が1件目だけを表示して残りを静かに握りつぶす・保存で消してしまう事故を防ぐために使う。
     * 読み取りのみで、DBは一切変更しない。
     */
    public boolean hasMultipleExpenses(int projectId) {
        List<ProjectParticipant> participants = participantMapper.findByProjectId(projectId);
        for (ProjectParticipant p : participants) {
            if (expenseMapper.findByProjectParticipantId(p.getId()).size() > 1) {
                return true;
            }
        }
        return false;
    }

    @Transactional
    public void saveProjectData(int projectId, ProjectSummaryExpense summary, List<ProjectParticipant> participants, List<Expense> expenses) {
        // Update summary expense
        var existingSummary = summaryExpenseMapper.findByProjectId(projectId);
        if (existingSummary != null) {
            summary.setId(existingSummary.getId());
            summaryExpenseMapper.update(summary);
        } else {
            summaryExpenseMapper.insert(summary);
        }

        // Recreate participants and expenses for simplicity
        // 経費(expenses)は participant の ON DELETE CASCADE によって自動削除されるため個別の削除は不要
        participantMapper.deleteByProjectId(projectId);
        
        for (int i = 0; i < participants.size(); i++) {
            ProjectParticipant p = participants.get(i);
            p.setProjectId(projectId);
            Expense e = (i < expenses.size()) ? expenses.get(i) : new Expense();

            // Handle Member Name and Auto-Registration
            String mName = p.getMemberName();
            // 氏名が空の行はスキップ（外部キー制約違反を防ぐ）
            if (mName == null || mName.trim().isEmpty()) {
                continue;
            }
            if (mName != null && !mName.trim().isEmpty()) {
                String departure = extractDeparture(e);
                Member existing = memberMapper.findByName(mName);
                if (existing == null) {
                    existing = new Member();
                    existing.setName(mName);
                    existing.setDeparturePoint(departure);
                    existing.setRole(normalizeRole(p.getMemberRole()));
                    existing.setAge(p.getMemberAge());
                    memberMapper.insert(existing);
                } else {
                    // 登録済みでも、入力値が登録内容と違えば上書きして登録し直す
                    boolean dirty = false;
                    if (departure != null && !departure.isEmpty() && !departure.equals(existing.getDeparturePoint())) {
                        existing.setDeparturePoint(departure); dirty = true;
                    }
                    String role = normalizeRole(p.getMemberRole());
                    if (role != null && !role.equals(existing.getRole())) { existing.setRole(role); dirty = true; }
                    if (p.getMemberAge() != null && !p.getMemberAge().equals(existing.getAge())) { existing.setAge(p.getMemberAge()); dirty = true; }
                    if (dirty) memberMapper.update(existing);
                }
                p.setMemberId(existing.getId());
            }

            participantMapper.insert(p);

            // 自家用車以外は距離をDB保存しない
            if (!"自家用車".equals(e.getTransportMethod())) {
                e.setTransportDistanceKm(null);
            }
            e.setProjectParticipantId(p.getId());
            expenseMapper.insert(e);
        }
    }

    /**
     * 活動の複製（入力ひな形目的）。
     * Project基本情報・参加者はコピーするが、決算書計上額に影響する金額項目（交通費・宿泊費・個人雑費・
     * 事業サマリ経費・旅行雑費単価/日数）は0にリセットし、二重計上を防ぐ。受領日は誤提出防止のためコピーしない。
     * 呼び出し元で「1参加者に複数Expense」を検出済みであることが前提（このメソッドは各参加者の先頭Expenseのみ扱う）。
     */
    @Transactional
    public int duplicateProject(Project source, List<ProjectParticipant> sourceParticipants) {
        Project copy = new Project();
        copy.setName("[コピー] " + source.getName());
        copy.setBudgetTypeId(source.getBudgetTypeId());
        copy.setTargetCategory(source.getTargetCategory());
        copy.setEventDate(source.getEventDate());
        copy.setLocationVenue(source.getLocationVenue());
        copy.setLocationAccommodation(source.getLocationAccommodation());
        copy.setScheduleContent(source.getScheduleContent());
        copy.setProjectOutcome(source.getProjectOutcome());
        copy.setAccommodationNights(source.getAccommodationNights());
        projectMapper.insert(copy); // is_printed は挿入時にDB defaultのFALSEになる
        int newProjectId = copy.getId();

        ProjectSummaryExpense newSummary = new ProjectSummaryExpense();
        newSummary.setProjectId(newProjectId);
        newSummary.setRentalCost(0);
        newSummary.setSuppliesCost(0);
        newSummary.setParkingCost(0);
        newSummary.setCompensationCost(0);
        newSummary.setServiceCost(0);
        newSummary.setTravelMiscCost(0);
        newSummary.setTravelMiscDays(0);
        summaryExpenseMapper.insert(newSummary);

        for (ProjectParticipant sp : sourceParticipants) {
            ProjectParticipant np = new ProjectParticipant();
            np.setProjectId(newProjectId);
            np.setMemberId(sp.getMemberId());
            np.setIsAccommodated(sp.getIsAccommodated());
            participantMapper.insert(np);

            List<Expense> exList = expenseMapper.findByProjectParticipantId(sp.getId());
            Expense se = exList.isEmpty() ? null : exList.get(0);
            Expense ne = new Expense();
            ne.setProjectParticipantId(np.getId());
            if (se != null) {
                ne.setExpenseDate(se.getExpenseDate());
                ne.setTransportMethod(se.getTransportMethod());
                ne.setTransportRoute(se.getTransportRoute());
                // transportDistanceKmはコピーしない: 編集画面のJS（自家用車の距離×単価の自動計算）が
                // 距離が入っているとページ読込時に交通費入力へ 距離×単価 を再セットしてしまい、
                // サーバー側で0にリセットした金額を保存前に静かに復活させてしまうため（実機検証で確認）。
            }
            ne.setTransportCost(0);
            ne.setAccommodationCost(0);
            ne.setMiscellaneousCost(0);
            ne.setReceiptDate(null); // 受領日は誤提出防止のためコピーしない
            expenseMapper.insert(ne);
        }

        return newProjectId;
    }

    /**
     * 出力画面からの一括印刷状態更新（Cycle 21）。全件更新できる場合だけコミットし、
     * 1件でも存在しないIDが混ざっていれば例外を投げて全件ロールバックする
     * （@Transactionalの既定の巻き戻し対象はRuntimeExceptionのため、明示的にRuntimeExceptionを使う）。
     * 呼び出し元のControllerでforループを回すだけの実装（コミット単位が行ごとになり得る）を避けるため、
     * このメソッド全体を1トランザクションにする。
     */
    @Transactional
    public void updatePrintedStatusAtomic(List<Integer> projectIds, boolean isPrinted) {
        if (projectIds == null || projectIds.isEmpty()) {
            throw new IllegalArgumentException("更新対象が選択されていません。");
        }
        java.util.LinkedHashSet<Integer> uniqueIds = new java.util.LinkedHashSet<>();
        for (Integer id : projectIds) {
            if (id != null) uniqueIds.add(id);
        }
        if (uniqueIds.isEmpty()) {
            throw new IllegalArgumentException("更新対象が選択されていません。");
        }
        for (Integer id : uniqueIds) {
            if (projectMapper.findById(id) == null) {
                throw new IllegalStateException("選択された活動(ID=" + id + ")が見つかりません。更新を中止しました。");
            }
        }
        for (Integer id : uniqueIds) {
            projectMapper.updatePrinted(id, isPrinted);
        }
    }

    private String extractDeparture(Expense e) {
        if (e == null || e.getTransportRoute() == null) return null;
        String route = e.getTransportRoute();
        if (route.contains("〜")) return route.split("〜")[0].trim();
        if (route.contains("～")) return route.split("～")[0].trim();
        return null;
    }

    private String normalizeRole(String role) {
        if (role == null) return null;
        role = role.trim();
        return role.isEmpty() ? null : role;
    }
}
