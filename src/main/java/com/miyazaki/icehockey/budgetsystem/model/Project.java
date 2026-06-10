package com.miyazaki.icehockey.budgetsystem.model;

public class Project {
    private Integer id;
    private String name;
    private Integer budgetTypeId;
    private String targetCategory;
    private java.time.LocalDate eventDate;
    private String locationVenue;
    private String locationAccommodation;
    private java.time.LocalDateTime createdAt;

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

    public java.time.LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(java.time.LocalDateTime createdAt) { this.createdAt = createdAt; }
}
