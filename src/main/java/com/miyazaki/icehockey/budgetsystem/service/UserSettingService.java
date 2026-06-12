package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.SystemSettingMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.UserMapper;
import com.miyazaki.icehockey.budgetsystem.model.SystemSetting;
import com.miyazaki.icehockey.budgetsystem.model.User;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class UserSettingService {

    @Autowired private UserMapper userMapper;
    @Autowired private SystemSettingMapper settingMapper;

    private static final String ACTIVE_USER_KEY = "active_user_id";

    public List<User> getAllUsers() {
        return userMapper.findAll();
    }

    public User getUserById(int id) {
        return userMapper.findById(id);
    }

    public void createUser(User user) {
        userMapper.insert(user);
    }

    public void updateUser(User user) {
        userMapper.update(user);
    }

    public Integer getActiveUserId() {
        SystemSetting s = settingMapper.findByKey(ACTIVE_USER_KEY);
        if (s == null || s.getSettingValue() == null) return null;
        try {
            return Integer.valueOf(s.getSettingValue());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public void setActiveUserId(int userId) {
        SystemSetting s = new SystemSetting();
        s.setSettingKey(ACTIVE_USER_KEY);
        s.setSettingValue(String.valueOf(userId));
        settingMapper.upsert(s);
    }

    public User getActiveUser() {
        Integer id = getActiveUserId();
        if (id == null) return null;
        return userMapper.findById(id);
    }
}
