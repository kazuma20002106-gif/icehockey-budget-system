package com.miyazaki.icehockey.budgetsystem.mapper;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import org.apache.ibatis.annotations.Mapper;
import java.util.List;

@Mapper
public interface ProjectMapper {
    List<Project> findAll();
    Project findById(int id);
    int insert(Project project);
}
