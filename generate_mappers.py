import os

base_dir = "src/main/java/com/miyazaki/icehockey/budgetsystem/"
mapper_dir = base_dir + "mapper/"
xml_dir = "src/main/resources/mapper/"

java_mappers = {
    "MemberMapper": """package com.miyazaki.icehockey.budgetsystem.mapper;
import com.miyazaki.icehockey.budgetsystem.model.Member;
import org.apache.ibatis.annotations.Mapper;
import java.util.List;

@Mapper
public interface MemberMapper {
    List<Member> findAll();
    void insert(Member member);
}
""",
    "BudgetTypeMapper": """package com.miyazaki.icehockey.budgetsystem.mapper;
import com.miyazaki.icehockey.budgetsystem.model.BudgetType;
import org.apache.ibatis.annotations.Mapper;
import java.util.List;

@Mapper
public interface BudgetTypeMapper {
    List<BudgetType> findAll();
}
""",
    "ProjectMapper": """package com.miyazaki.icehockey.budgetsystem.mapper;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import org.apache.ibatis.annotations.Mapper;
import java.util.List;

@Mapper
public interface ProjectMapper {
    List<Project> findAll();
    void insert(Project project);
}
"""
}

xml_mappers = {
    "MemberMapper.xml": """<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.miyazaki.icehockey.budgetsystem.mapper.MemberMapper">
    <select id="findAll" resultType="com.miyazaki.icehockey.budgetsystem.model.Member">
        SELECT * FROM members ORDER BY id;
    </select>
    <insert id="insert" useGeneratedKeys="true" keyProperty="id">
        INSERT INTO members (name, age, grade, role) VALUES (#{name}, #{age}, #{grade}, #{role})
    </insert>
</mapper>
""",
    "BudgetTypeMapper.xml": """<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.miyazaki.icehockey.budgetsystem.mapper.BudgetTypeMapper">
    <select id="findAll" resultType="com.miyazaki.icehockey.budgetsystem.model.BudgetType">
        SELECT * FROM budget_types ORDER BY id;
    </select>
</mapper>
""",
    "ProjectMapper.xml": """<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper">
    <select id="findAll" resultType="com.miyazaki.icehockey.budgetsystem.model.Project">
        SELECT * FROM projects ORDER BY event_date DESC;
    </select>
    <insert id="insert" useGeneratedKeys="true" keyProperty="id">
        INSERT INTO projects (name, budget_type_id, target_category, event_date, location_venue, location_accommodation)
        VALUES (#{name}, #{budgetTypeId}, #{targetCategory}, #{eventDate}, #{locationVenue}, #{locationAccommodation})
    </insert>
</mapper>
"""
}

for name, content in java_mappers.items():
    with open(mapper_dir + f"{name}.java", "w", encoding="utf-8") as f:
        f.write(content)

for name, content in xml_mappers.items():
    with open(xml_dir + f"{name}", "w", encoding="utf-8") as f:
        f.write(content)

print("Generated mappers.")
