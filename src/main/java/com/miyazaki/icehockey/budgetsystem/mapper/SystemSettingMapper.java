package com.miyazaki.icehockey.budgetsystem.mapper;

import com.miyazaki.icehockey.budgetsystem.model.SystemSetting;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface SystemSettingMapper {
    SystemSetting findByKey(String key);
    void upsert(SystemSetting setting);
}
