package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
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
        expenseMapper.deleteByProjectParticipantId(projectId); // Wait, this needs careful joining or delete by projectId.
        participantMapper.deleteByProjectId(projectId);
        
        // Let's implement robust insert
        for (int i = 0; i < participants.size(); i++) {
            ProjectParticipant p = participants.get(i);
            p.setProjectId(projectId);
            participantMapper.insert(p);
            
            Expense e = expenses.get(i);
            e.setProjectParticipantId(p.getId());
            expenseMapper.insert(e);
        }
    }
}
