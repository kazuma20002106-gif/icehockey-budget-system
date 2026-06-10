package com.miyazaki.icehockey.budgetsystem.mapper;
import com.miyazaki.icehockey.budgetsystem.model.Member;
import org.apache.ibatis.annotations.Mapper;
import java.util.List;

@Mapper
public interface MemberMapper {
    List<Member> findAll();
    Member findByName(String name);
    void insert(Member member);
    void update(Member member);
    void delete(int id);
}
