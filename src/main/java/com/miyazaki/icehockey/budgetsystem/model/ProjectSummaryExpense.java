package com.miyazaki.icehockey.budgetsystem.model;

public class ProjectSummaryExpense {
    private Integer id;
    private Integer projectId;
    private Integer rentalCost;
    private Integer suppliesCost;
    private Integer parkingCost;
    private Integer compensationCost;
    private Integer serviceCost;
    private Integer travelMiscCost;  // 旅行雑費 単価（1人1日あたり）
    private Integer travelMiscDays;  // 旅行雑費 日数

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public Integer getProjectId() { return projectId; }
    public void setProjectId(Integer projectId) { this.projectId = projectId; }

    public Integer getRentalCost() { return rentalCost; }
    public void setRentalCost(Integer rentalCost) { this.rentalCost = rentalCost; }

    public Integer getSuppliesCost() { return suppliesCost; }
    public void setSuppliesCost(Integer suppliesCost) { this.suppliesCost = suppliesCost; }

    public Integer getParkingCost() { return parkingCost; }
    public void setParkingCost(Integer parkingCost) { this.parkingCost = parkingCost; }

    public Integer getCompensationCost() { return compensationCost; }
    public void setCompensationCost(Integer compensationCost) { this.compensationCost = compensationCost; }

    public Integer getServiceCost() { return serviceCost; }
    public void setServiceCost(Integer serviceCost) { this.serviceCost = serviceCost; }

    public Integer getTravelMiscCost() { return travelMiscCost; }
    public void setTravelMiscCost(Integer travelMiscCost) { this.travelMiscCost = travelMiscCost; }

    public Integer getTravelMiscDays() { return travelMiscDays; }
    public void setTravelMiscDays(Integer travelMiscDays) { this.travelMiscDays = travelMiscDays; }
}
