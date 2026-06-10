package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.mapper.MemberMapper;
import com.miyazaki.icehockey.budgetsystem.model.Member;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

@Controller
@RequestMapping("/members")
public class MemberController {

    @Autowired
    private MemberMapper memberMapper;

    @GetMapping
    public String index(Model model) {
        model.addAttribute("members", memberMapper.findAll());
        return "members/index";
    }

    @PostMapping("/add")
    public String add(Member member) {
        memberMapper.insert(member);
        return "redirect:/members";
    }

    @PostMapping("/{id}/update")
    public String update(@PathVariable("id") int id, Member member) {
        member.setId(id);
        memberMapper.update(member);
        return "redirect:/members";
    }

    @PostMapping("/{id}/delete")
    public String delete(@PathVariable("id") int id) {
        memberMapper.delete(id);
        return "redirect:/members";
    }
}
