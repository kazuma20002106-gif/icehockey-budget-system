package com.miyazaki.icehockey.budgetsystem.model;

import java.time.LocalDate;
import java.util.List;

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

    /**
     * 1参加者に複数Expenseがある場合の表示用集約。
     * 数値項目（交通費・宿泊費・雑費）は全件合算し、非数値項目（期日・交通手段・区間・距離・受領日）は先頭1件を踏襲する。
     * exListが空またはnullならnullを返す。
     */
    public static Expense aggregate(List<Expense> exList) {
        if (exList == null || exList.isEmpty()) return null;
        Expense first = exList.get(0);
        Expense agg = new Expense();
        agg.setExpenseDate(first.getExpenseDate());
        agg.setTransportMethod(first.getTransportMethod());
        agg.setTransportRoute(first.getTransportRoute());
        agg.setTransportDistanceKm(first.getTransportDistanceKm());
        agg.setReceiptDate(first.getReceiptDate());

        int transport = 0, accommodation = 0, misc = 0;
        for (Expense e : exList) {
            if (e.getTransportCost() != null) transport += e.getTransportCost();
            if (e.getAccommodationCost() != null) accommodation += e.getAccommodationCost();
            if (e.getMiscellaneousCost() != null) misc += e.getMiscellaneousCost();
        }
        agg.setTransportCost(transport);
        agg.setAccommodationCost(accommodation);
        agg.setMiscellaneousCost(misc);
        return agg;
    }
}
