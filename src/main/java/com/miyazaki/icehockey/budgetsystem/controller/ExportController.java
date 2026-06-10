package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.service.ExcelExportService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletResponse;
import java.util.List;

@Controller
@RequestMapping("/export")
public class ExportController {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private ExcelExportService excelExportService;

    @GetMapping
    public String index(Model model) {
        model.addAttribute("projects", projectMapper.findAll());
        // In a real app, we'd calculate the accumulated sums here for the dashboard.
        // For now, we will do it via the service if requested or just let the user select.
        return "export/index";
    }

    @PostMapping("/download")
    public void download(@RequestParam("exportType") String exportType,
                         @RequestParam(value = "projectIds", required = false) List<Integer> projectIds,
                         HttpServletResponse response) throws Exception {
        
        if (projectIds == null || projectIds.isEmpty()) {
            response.sendRedirect("/export?error=no_selection");
            return;
        }

        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        String filename = "export_" + exportType + ".xlsx";
        response.setHeader("Content-Disposition", "attachment; filename=\"" + filename + "\"");
        
        if ("2-2".equals(exportType)) {
            excelExportService.exportForm22Summary(projectIds, response.getOutputStream());
        } else if ("2-4".equals(exportType)) {
            excelExportService.exportForm24(projectIds, response.getOutputStream());
        } else if ("2-5".equals(exportType)) {
            excelExportService.exportForm25(projectIds, response.getOutputStream());
        } else if ("2-6".equals(exportType)) {
            excelExportService.exportForm26(projectIds, response.getOutputStream());
        }
    }
}
