package com.miyazaki.icehockey.budgetsystem.model;

public class Expense {
    private Integer id;
    private Integer projectParticipantId;
    private String transportMethod;
    private Integer transportCost;
    private Integer accommodationCost;
    private Integer miscellaneousCost;

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public Integer getProjectParticipantId() { return projectParticipantId; }
    public void setProjectParticipantId(Integer projectParticipantId) { this.projectParticipantId = projectParticipantId; }

    public String getTransportMethod() { return transportMethod; }
    public void setTransportMethod(String transportMethod) { this.transportMethod = transportMethod; }

    public Integer getTransportCost() { return transportCost; }
    public void setTransportCost(Integer transportCost) { this.transportCost = transportCost; }

    public Integer getAccommodationCost() { return accommodationCost; }
    public void setAccommodationCost(Integer accommodationCost) { this.accommodationCost = accommodationCost; }

    public Integer getMiscellaneousCost() { return miscellaneousCost; }
    public void setMiscellaneousCost(Integer miscellaneousCost) { this.miscellaneousCost = miscellaneousCost; }
}
