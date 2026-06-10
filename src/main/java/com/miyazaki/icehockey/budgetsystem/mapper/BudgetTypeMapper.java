package com.miyazaki.icehockey.budgetsystem.mapper;
import com.miyazaki.icehockey.budgetsystem.model.BudgetType;
import org.apache.ibatis.annotations.Mapper;
import java.util.List;

@Mapper
public interface BudgetTypeMapper {
    List<BudgetType> findAll();
}
