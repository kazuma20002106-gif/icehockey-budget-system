package com.miyazaki.icehockey.budgetsystem.mapper;

import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface ProjectSummaryExpenseMapper {
    int insert(ProjectSummaryExpense expense);
    ProjectSummaryExpense findByProjectId(@Param("projectId") int projectId);
    int update(ProjectSummaryExpense expense);
}
