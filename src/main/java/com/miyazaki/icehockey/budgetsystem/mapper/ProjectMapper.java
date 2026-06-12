package com.miyazaki.icehockey.budgetsystem.mapper;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import java.util.List;

@Mapper
public interface ProjectMapper {
    List<Project> findAll();
    Project findById(int id);
    List<Project> findFiltered(@Param("fiscalYear") Integer fiscalYear, @Param("budgetTypeId") Integer budgetTypeId, @Param("month") Integer month);
    List<Project> findByFiscalYearOrdered(@Param("fiscalYear") Integer fiscalYear);
    int insert(Project project);
    int update(Project project);
    int delete(int id);
}
