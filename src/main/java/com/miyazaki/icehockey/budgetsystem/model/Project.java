package com.miyazaki.icehockey.budgetsystem.model;

public class Project {
    private Integer id;
    private String name;
    private Integer budgetTypeId;
    private String targetCategory;
    private java.time.LocalDate eventDate;
    private String locationVenue;
    private String locationAccommodation;
    private String scheduleContent; // 日程及び内容
    private String projectOutcome; // 事業の成果
    private Integer accommodationNights; // 宿泊日数（泊数）
    private java.time.LocalDateTime createdAt;
    private Boolean isPrinted; // 印刷ステータス（未印刷/印刷済）。手動管理のみ、Excel出力での自動変更はしない

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Integer getBudgetTypeId() { return budgetTypeId; }
    public void setBudgetTypeId(Integer budgetTypeId) { this.budgetTypeId = budgetTypeId; }

    public String getTargetCategory() { return targetCategory; }
    public void setTargetCategory(String targetCategory) { this.targetCategory = targetCategory; }

    public java.time.LocalDate getEventDate() { return eventDate; }
    public void setEventDate(java.time.LocalDate eventDate) { this.eventDate = eventDate; }

    public String getLocationVenue() { return locationVenue; }
    public void setLocationVenue(String locationVenue) { this.locationVenue = locationVenue; }

    public String getLocationAccommodation() { return locationAccommodation; }
    public void setLocationAccommodation(String locationAccommodation) { this.locationAccommodation = locationAccommodation; }

    public String getScheduleContent() { return scheduleContent; }
    public void setScheduleContent(String scheduleContent) { this.scheduleContent = scheduleContent; }

    public String getProjectOutcome() { return projectOutcome; }
    public void setProjectOutcome(String projectOutcome) { this.projectOutcome = projectOutcome; }

    public Integer getAccommodationNights() { return accommodationNights; }
    public void setAccommodationNights(Integer accommodationNights) { this.accommodationNights = accommodationNights; }

    // 年度（日本の会計年度：4月始まり）を活動日から導出
    public Integer getFiscalYear() {
        if (eventDate == null) return null;
        int y = eventDate.getYear();
        return eventDate.getMonthValue() >= 4 ? y : y - 1;
    }

    public java.time.LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(java.time.LocalDateTime createdAt) { this.createdAt = createdAt; }

    public Boolean getIsPrinted() { return isPrinted; }
    public void setIsPrinted(Boolean isPrinted) { this.isPrinted = isPrinted; }
}
