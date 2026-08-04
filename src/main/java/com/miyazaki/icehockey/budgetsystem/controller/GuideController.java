package com.miyazaki.icehockey.budgetsystem.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

// Cycle 22: 初見利用者向け「？ 使い方」常設ガイド。GET専用・DB/Service/Repositoryへは一切アクセスしない。
@Controller
public class GuideController {

    @GetMapping("/guide")
    public String guide() {
        return "guide/index";
    }
}
