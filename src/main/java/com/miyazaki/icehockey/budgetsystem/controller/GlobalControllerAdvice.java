package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.service.UserSettingService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ModelAttribute;

@ControllerAdvice
public class GlobalControllerAdvice {

    @Autowired private UserSettingService userSettingService;

    @ModelAttribute
    public void addGlobalAttributes(Model model, HttpServletRequest request) {
        try {
            model.addAttribute("users", userSettingService.getAllUsers());
            model.addAttribute("activeUser", userSettingService.getActiveUser());
        } catch (Exception e) {
            model.addAttribute("users", java.util.Collections.emptyList());
            model.addAttribute("activeUser", null);
        }
        model.addAttribute("currentRequestUri", request.getRequestURI());
    }
}
