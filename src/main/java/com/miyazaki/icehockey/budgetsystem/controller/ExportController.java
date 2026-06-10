package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import com.miyazaki.icehockey.budgetsystem.service.ExcelExportService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletResponse;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Controller
@RequestMapping("/export")
public class ExportController {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private ExcelExportService excelExportService;
    @Autowired private ProjectSummaryExpenseMapper summaryMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;

    @GetMapping
    public String index(Model model) {
        model.addAttribute("projects", projectMapper.findAll());
        return "export/index";
    }

    @PostMapping("/preview")
    public String preview(@RequestParam("exportType") String exportType,
                          @RequestParam(value = "projectIds", required = false) List<Integer> projectIds,
                          Model model) {
        if (projectIds == null || projectIds.isEmpty()) {
            return "redirect:/export?error=no_selection";
        }

        model.addAttribute("exportType", exportType);
        model.addAttribute("projectIds", projectIds);

        if ("2-2".equals(exportType)) {
            int totalRental = 0, totalSupplies = 0, totalParking = 0, totalCompensation = 0, totalService = 0;
            int totalTransport = 0, totalAccommodation = 0;

            for (int id : projectIds) {
                ProjectSummaryExpense sum = summaryMapper.findByProjectId(id);
                if (sum != null) {
                    totalRental += sum.getRentalCost();
                    totalSupplies += sum.getSuppliesCost();
                    totalParking += sum.getParkingCost();
                    totalCompensation += sum.getCompensationCost();
                    totalService += sum.getServiceCost();
                }
                
                List<ProjectParticipant> parts = participantMapper.findByProjectId(id);
                for (ProjectParticipant p : parts) {
                    List<Expense> exList = expenseMapper.findByProjectParticipantId(p.getId());
                    if (!exList.isEmpty()) {
                        Expense ex = exList.get(0);
                        totalTransport += ex.getTransportCost();
                        totalAccommodation += ex.getAccommodationCost();
                    }
                }
            }

            model.addAttribute("totalRental", totalRental);
            model.addAttribute("totalSupplies", totalSupplies);
            model.addAttribute("totalParking", totalParking);
            model.addAttribute("totalCompensation", totalCompensation);
            model.addAttribute("totalService", totalService);
            model.addAttribute("totalTransport", totalTransport);
            model.addAttribute("totalAccommodation", totalAccommodation);
            model.addAttribute("grandTotal", totalRental + totalSupplies + totalParking + totalCompensation + totalService + totalTransport + totalAccommodation);

        } else {
            List<Map<String, Object>> previewProjects = new ArrayList<>();
            for (int id : projectIds) {
                Project p = projectMapper.findById(id);
                if(p != null) {
                    Map<String, Object> pd = new HashMap<>();
                    pd.put("project", p);
                    
                    ProjectSummaryExpense sum = summaryMapper.findByProjectId(id);
                    pd.put("summary", sum != null ? sum : new ProjectSummaryExpense());
                    
                    List<ProjectParticipant> parts = participantMapper.findByProjectId(id);
                    int transportSum = 0, accommodationSum = 0;
                    for (ProjectParticipant part : parts) {
                        List<Expense> exList = expenseMapper.findByProjectParticipantId(part.getId());
                        if (!exList.isEmpty()) {
                            Expense ex = exList.get(0);
                            part.setExpense(ex);
                            transportSum += ex.getTransportCost();
                            accommodationSum += ex.getAccommodationCost();
                        }
                    }
                    pd.put("participants", parts);
                    pd.put("transportSum", transportSum);
                    pd.put("accommodationSum", accommodationSum);
                    
                    previewProjects.add(pd);
                }
            }
            model.addAttribute("previewProjects", previewProjects);
        }

        return "export/preview";
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

    @GetMapping("/test-cells")
    @ResponseBody
    public String testCells() throws Exception {
        org.springframework.core.io.ClassPathResource resource = new org.springframework.core.io.ClassPathResource("書類.xlsx");
        try (java.io.InputStream is = resource.getInputStream();
             org.apache.poi.ss.usermodel.Workbook workbook = org.apache.poi.ss.usermodel.WorkbookFactory.create(is)) {
            StringBuilder sb = new StringBuilder();
            sb.append("--- Sheets ---\n");
            for (int i = 0; i < workbook.getNumberOfSheets(); i++) {
                sb.append(i).append(": ").append(workbook.getSheetName(i)).append("\n");
            }
            
            org.apache.poi.ss.usermodel.Sheet sheet = workbook.getSheet("様式２－６①事業別領収書１（選手強化）");
            if (sheet != null) {
                sb.append("\n--- Title row for 2-6 (1) ---\n");
                for (int c = 0; c < 20; c++) {
                    org.apache.poi.ss.usermodel.Cell cell = sheet.getRow(1) != null ? sheet.getRow(1).getCell(c) : null;
                    if (cell != null && cell.getCellType() == org.apache.poi.ss.usermodel.CellType.STRING) {
                        sb.append("R1C").append(c).append("=").append(cell.getStringCellValue()).append("\n");
                    }
                    cell = sheet.getRow(2) != null ? sheet.getRow(2).getCell(c) : null;
                    if (cell != null && cell.getCellType() == org.apache.poi.ss.usermodel.CellType.STRING) {
                        sb.append("R2C").append(c).append("=").append(cell.getStringCellValue()).append("\n");
                    }
                }
            }
            return sb.toString();
        }
    }
}
