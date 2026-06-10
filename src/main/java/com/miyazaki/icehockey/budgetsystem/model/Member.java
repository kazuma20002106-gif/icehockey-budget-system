package com.miyazaki.icehockey.budgetsystem.model;

public class Member {
    private Integer id;
    private String name;
    private Integer age;
    private String grade;
    private String role;
    private String departurePoint;

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Integer getAge() { return age; }
    public void setAge(Integer age) { this.age = age; }

    public String getGrade() { return grade; }
    public void setGrade(String grade) { this.grade = grade; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public String getDeparturePoint() { return departurePoint; }
    public void setDeparturePoint(String departurePoint) { this.departurePoint = departurePoint; }
}
