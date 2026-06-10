package com.miyazaki.icehockey.budgetsystem.model;

import java.util.ArrayList;
import java.util.List;

public class ProjectForm {
    private ProjectSummaryExpense summary = new ProjectSummaryExpense();
    private List<ProjectParticipant> participants = new ArrayList<>();
    private List<Expense> expenses = new ArrayList<>();

    public ProjectSummaryExpense getSummary() { return summary; }
    public void setSummary(ProjectSummaryExpense summary) { this.summary = summary; }
    public List<ProjectParticipant> getParticipants() { return participants; }
    public void setParticipants(List<ProjectParticipant> participants) { this.participants = participants; }
    public List<Expense> getExpenses() { return expenses; }
    public void setExpenses(List<Expense> expenses) { this.expenses = expenses; }
}
