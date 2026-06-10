package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.mapper.MemberMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class DashboardController {

    @Autowired
    private MemberMapper memberMapper;

    @Autowired
    private ProjectMapper projectMapper;

    @GetMapping("/")
    public String index(Model model) {
        var members = memberMapper.findAll();
        var projects = projectMapper.findAll();
        
        model.addAttribute("memberCount", members.size());
        model.addAttribute("projectCount", projects.size());
        model.addAttribute("projects", projects);
        
        return "index";
    }
}
