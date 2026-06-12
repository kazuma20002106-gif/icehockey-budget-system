package com.miyazaki.icehockey.budgetsystem.mapper;

import com.miyazaki.icehockey.budgetsystem.model.RouteMaster;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface RouteMasterMapper {
    RouteMaster findByRoute(@Param("departure") String departure, @Param("destination") String destination);
    void upsert(RouteMaster routeMaster);
}
