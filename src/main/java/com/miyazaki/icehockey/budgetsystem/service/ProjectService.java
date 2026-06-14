package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.MemberMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Member;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ProjectService {

    @Autowired
    private ProjectParticipantMapper participantMapper;

    @Autowired
    private ExpenseMapper expenseMapper;

    @Autowired
    private ProjectSummaryExpenseMapper summaryExpenseMapper;

    @Autowired
    private MemberMapper memberMapper;

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
