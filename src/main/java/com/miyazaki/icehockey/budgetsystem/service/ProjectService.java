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
        expenseMapper.deleteByProjectParticipantId(projectId);
        participantMapper.deleteByProjectId(projectId);
        
        for (int i = 0; i < participants.size(); i++) {
            ProjectParticipant p = participants.get(i);
            p.setProjectId(projectId);
            Expense e = expenses.get(i);

            // Handle Member Name and Auto-Registration
            String mName = p.getMemberName();
            if (mName != null && !mName.trim().isEmpty()) {
                Member existing = memberMapper.findByName(mName);
                if (existing == null) {
                    existing = new Member();
                    existing.setName(mName);
                    if (e != null && e.getTransportRoute() != null) {
                        String route = e.getTransportRoute();
                        if (route.contains("〜")) existing.setDeparturePoint(route.split("〜")[0].trim());
                        else if (route.contains("～")) existing.setDeparturePoint(route.split("～")[0].trim());
                    }
                    memberMapper.insert(existing);
                } else {
                    if (e != null && e.getTransportRoute() != null && (existing.getDeparturePoint() == null || existing.getDeparturePoint().isEmpty())) {
                        String route = e.getTransportRoute();
                        if (route.contains("〜")) { existing.setDeparturePoint(route.split("〜")[0].trim()); memberMapper.update(existing); }
                        else if (route.contains("～")) { existing.setDeparturePoint(route.split("～")[0].trim()); memberMapper.update(existing); }
                    }
                }
                p.setMemberId(existing.getId());
            }

            participantMapper.insert(p);
            
            e.setProjectParticipantId(p.getId());
            expenseMapper.insert(e);
        }
    }
}
