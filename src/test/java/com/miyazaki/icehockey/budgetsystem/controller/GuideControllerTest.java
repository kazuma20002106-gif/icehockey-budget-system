package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.service.UserSettingService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Collections;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

// Cycle 22: /guide はGET専用でDB接続を必要としないため、DBに触れないMVCスライステストで到達性のみ確認する。
@WebMvcTest(GuideController.class)
class GuideControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserSettingService userSettingService;

    @Test
    void guide_returns200AndGuideView() throws Exception {
        org.mockito.Mockito.when(userSettingService.getAllUsers()).thenReturn(Collections.emptyList());
        org.mockito.Mockito.when(userSettingService.getActiveUser()).thenReturn(null);

        mockMvc.perform(get("/guide"))
                .andExpect(status().isOk())
                .andExpect(view().name("guide/index"));
    }
}
