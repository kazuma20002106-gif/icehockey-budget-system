package com.miyazaki.icehockey.budgetsystem.mapper;

import com.miyazaki.icehockey.budgetsystem.model.User;
import org.apache.ibatis.annotations.Mapper;
import java.util.List;

@Mapper
public interface UserMapper {
    List<User> findAll();
    User findById(int id);
    User findByName(String name);
    void insert(User user);
    void update(User user);
}
