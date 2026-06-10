package com.miyazaki.icehockey.budgetsystem.model;

public class ProjectParticipant {
    private int id;
    private int projectId;
    private int memberId;
    private boolean isAccommodated;
    private Member member;

    // Transient fields for UI and Export
    private String memberName;
    private String memberRole;
    private Expense expense;

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public int getProjectId() { return projectId; }
    public void setProjectId(int projectId) { this.projectId = projectId; }

    public int getMemberId() { return memberId; }
    public void setMemberId(int memberId) { this.memberId = memberId; }

    public boolean getIsAccommodated() { return isAccommodated; }
    public void setIsAccommodated(boolean isAccommodated) { this.isAccommodated = isAccommodated; }

    public Member getMember() { return member; }
    public void setMember(Member member) { this.member = member; }

    public String getMemberName() { return memberName; }
    public void setMemberName(String memberName) { this.memberName = memberName; }

    public String getMemberRole() { return memberRole; }
    public void setMemberRole(String memberRole) { this.memberRole = memberRole; }

    public Expense getExpense() { return expense; }
    public void setExpense(Expense expense) { this.expense = expense; }
}
