package com.miyazaki.icehockey.budgetsystem.model;

public class User {
    private Integer id;
    private String name;
    private String phoneNumber;

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }

    public String getFormattedPhoneNumber() {
        if (phoneNumber == null) return "";
        String digits = phoneNumber.replaceAll("[^0-9]", "");
        if (digits.length() == 11) {
            return digits.substring(0, 3) + "-" + digits.substring(3, 7) + "-" + digits.substring(7);
        } else if (digits.length() == 10) {
            return digits.substring(0, 4) + "-" + digits.substring(4, 6) + "-" + digits.substring(6);
        }
        return phoneNumber;
    }
}
