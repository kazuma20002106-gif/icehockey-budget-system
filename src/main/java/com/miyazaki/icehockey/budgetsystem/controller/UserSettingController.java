package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.model.User;
import com.miyazaki.icehockey.budgetsystem.service.UserSettingService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;

@Controller
@RequestMapping("/users")
public class UserSettingController {

    @Autowired private UserSettingService userSettingService;

    @PostMapping("/switch")
    public String switchUser(@RequestParam int userId,
                             @RequestParam(defaultValue = "/activity") String redirect) {
        userSettingService.setActiveUserId(userId);
        return "redirect:" + redirect;
    }

    @GetMapping("/new")
    public String newUserForm(@RequestParam(defaultValue = "/activity") String redirect, Model model) {
        model.addAttribute("user", new User());
        model.addAttribute("redirect", redirect);
        return "users/form";
    }

    @PostMapping("/new")
    public String createUser(@ModelAttribute User user,
                              @RequestParam(defaultValue = "/activity") String redirect) {
        userSettingService.createUser(user);
        userSettingService.setActiveUserId(user.getId());
        return "redirect:" + redirect;
    }

    @GetMapping("/edit/{id}")
    public String editUserForm(@PathVariable int id,
                               @RequestParam(defaultValue = "/activity") String redirect,
                               Model model) {
        model.addAttribute("user", userSettingService.getUserById(id));
        model.addAttribute("redirect", redirect);
        return "users/form";
    }

    @PostMapping("/edit/{id}")
    public String updateUser(@PathVariable int id, @ModelAttribute User user,
                              @RequestParam(defaultValue = "/activity") String redirect) {
        user.setId(id);
        userSettingService.updateUser(user);
        return "redirect:" + redirect;
    }
}
