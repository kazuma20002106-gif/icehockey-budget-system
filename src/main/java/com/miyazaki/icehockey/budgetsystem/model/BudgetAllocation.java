package com.miyazaki.icehockey.budgetsystem.model;

import java.time.LocalDateTime;

public class BudgetAllocation {
    private Integer id;
    private Integer fiscalYear;
    private Integer budgetTypeId;
    private String targetCategory;
    private Long allocatedAmount;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public Integer getFiscalYear() { return fiscalYear; }
    public void setFiscalYear(Integer fiscalYear) { this.fiscalYear = fiscalYear; }

    public Integer getBudgetTypeId() { return budgetTypeId; }
    public void setBudgetTypeId(Integer budgetTypeId) { this.budgetTypeId = budgetTypeId; }

    public String getTargetCategory() { return targetCategory; }
    public void setTargetCategory(String targetCategory) { this.targetCategory = targetCategory; }

    public Long getAllocatedAmount() { return allocatedAmount; }
    public void setAllocatedAmount(Long allocatedAmount) { this.allocatedAmount = allocatedAmount; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
