package com.miyazaki.icehockey.budgetsystem.model;

import java.util.ArrayList;
import java.util.List;

/**
 * 活動日入力（新規・編集）の1ページ統合フォーム。
 * 基本情報(Project)・施設その他経費(Summary)・参加者名簿(2-5)・個人別支出(2-6)をまとめて受け取る。
 */
public class ActivityForm {
    private Project project = new Project();
    private ProjectSummaryExpense summary = new ProjectSummaryExpense();
    private List<ProjectParticipant> participants = new ArrayList<>();
    private List<Expense> expenses = new ArrayList<>();

    public Project getProject() { return project; }
    public void setProject(Project project) { this.project = project; }

    public ProjectSummaryExpense getSummary() { return summary; }
    public void setSummary(ProjectSummaryExpense summary) { this.summary = summary; }

    public List<ProjectParticipant> getParticipants() { return participants; }
    public void setParticipants(List<ProjectParticipant> participants) { this.participants = participants; }

    public List<Expense> getExpenses() { return expenses; }
    public void setExpenses(List<Expense> expenses) { this.expenses = expenses; }
}
