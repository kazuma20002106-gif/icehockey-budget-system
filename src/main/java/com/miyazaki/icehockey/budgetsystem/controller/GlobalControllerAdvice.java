package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.service.UserSettingService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ModelAttribute;

@ControllerAdvice
public class GlobalControllerAdvice {

    @Autowired private UserSettingService userSettingService;

    @ModelAttribute
    public void addGlobalAttributes(Model model) {
        try {
            model.addAttribute("users", userSettingService.getAllUsers());
            model.addAttribute("activeUser", userSettingService.getActiveUser());
        } catch (Exception e) {
            // DB未初期化時など起動直後の例外を無視
        }
    }
}
