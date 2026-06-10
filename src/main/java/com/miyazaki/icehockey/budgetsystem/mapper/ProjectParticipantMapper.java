package com.miyazaki.icehockey.budgetsystem.mapper;

import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import java.util.List;

@Mapper
public interface ProjectParticipantMapper {
    int insert(ProjectParticipant participant);
    List<ProjectParticipant> findByProjectId(@Param("projectId") int projectId);
    int deleteByProjectId(@Param("projectId") int projectId);
}
