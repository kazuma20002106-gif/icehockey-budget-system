package com.miyazaki.icehockey.budgetsystem.mapper;

import com.miyazaki.icehockey.budgetsystem.model.BudgetAllocation;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface BudgetAllocationMapper {
    List<BudgetAllocation> findByFiscalYear(@Param("fiscalYear") int fiscalYear);
    BudgetAllocation findOne(@Param("fiscalYear") int fiscalYear, @Param("budgetTypeId") int budgetTypeId, @Param("targetCategory") String targetCategory);
    int upsert(BudgetAllocation allocation);
}
