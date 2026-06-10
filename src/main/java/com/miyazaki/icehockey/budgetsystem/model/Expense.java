package com.miyazaki.icehockey.budgetsystem.model;

import java.time.LocalDate;

public class Expense {
    private Integer id;
    private Integer projectParticipantId;
    
    private LocalDate expenseDate; // 期日
    private String transportMethod; // 航空機・バス or 電車・車
    private String transportRoute; // 区間
    private Integer transportDistanceKm; // 距離
    
    private Integer transportCost;
    private Integer accommodationCost;
    private Integer miscellaneousCost;
    
    private LocalDate receiptDate; // 受領日

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public Integer getProjectParticipantId() { return projectParticipantId; }
    public void setProjectParticipantId(Integer projectParticipantId) { this.projectParticipantId = projectParticipantId; }

    public LocalDate getExpenseDate() { return expenseDate; }
    public void setExpenseDate(LocalDate expenseDate) { this.expenseDate = expenseDate; }

    public String getTransportMethod() { return transportMethod; }
    public void setTransportMethod(String transportMethod) { this.transportMethod = transportMethod; }

    public String getTransportRoute() { return transportRoute; }
    public void setTransportRoute(String transportRoute) { this.transportRoute = transportRoute; }

    public Integer getTransportDistanceKm() { return transportDistanceKm; }
    public void setTransportDistanceKm(Integer transportDistanceKm) { this.transportDistanceKm = transportDistanceKm; }

    public Integer getTransportCost() { return transportCost; }
    public void setTransportCost(Integer transportCost) { this.transportCost = transportCost; }

    public Integer getAccommodationCost() { return accommodationCost; }
    public void setAccommodationCost(Integer accommodationCost) { this.accommodationCost = accommodationCost; }

    public Integer getMiscellaneousCost() { return miscellaneousCost; }
    public void setMiscellaneousCost(Integer miscellaneousCost) { this.miscellaneousCost = miscellaneousCost; }

    public LocalDate getReceiptDate() { return receiptDate; }
    public void setReceiptDate(LocalDate receiptDate) { this.receiptDate = receiptDate; }
}
