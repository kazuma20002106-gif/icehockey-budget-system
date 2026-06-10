package com.miyazaki.icehockey.budgetsystem.model;

public class ProjectParticipant {
    private Integer id;
    private Integer projectId;
    private Integer memberId;
    private Boolean isAccommodated;
    private Member member;

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public Integer getProjectId() { return projectId; }
    public void setProjectId(Integer projectId) { this.projectId = projectId; }

    public Integer getMemberId() { return memberId; }
    public void setMemberId(Integer memberId) { this.memberId = memberId; }

    public Boolean getIsAccommodated() { return isAccommodated; }
    public void setIsAccommodated(Boolean isAccommodated) { this.isAccommodated = isAccommodated; }

    public Member getMember() { return member; }
    public void setMember(Member member) { this.member = member; }
}
