package com.miyazaki.icehockey.budgetsystem.mapper;

import com.miyazaki.icehockey.budgetsystem.model.Expense;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import java.util.List;

@Mapper
public interface ExpenseMapper {
    int insert(Expense expense);
    List<Expense> findByProjectParticipantId(@Param("projectParticipantId") int projectParticipantId);
    int deleteByProjectParticipantId(@Param("projectParticipantId") int projectParticipantId);
}
