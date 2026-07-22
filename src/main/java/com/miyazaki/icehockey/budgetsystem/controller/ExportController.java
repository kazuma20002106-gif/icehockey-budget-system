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
import com.miyazaki.icehockey.budgetsystem.service.UserSettingService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletResponse;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;

@Controller
@RequestMapping("/export")
public class ExportController {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private ExcelExportService excelExportService;
    @Autowired private ProjectSummaryExpenseMapper summaryMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;
    @Autowired private UserSettingService userSettingService;

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
        model.addAttribute("activeUser", userSettingService.getActiveUser());

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
        } else {
            // "all" またはその他: 2-4/2-5/2-6 まとめて出力
            excelExportService.exportAllFormsForProjects(projectIds, response.getOutputStream());
        }
    }

    // ===== Cycle 12C: 年度末決算ファイル出力の専用導線（提出情報入力→タブプレビュー→ダウンロード） =====

    @GetMapping("/year/setup")
    public String yearSetup(@RequestParam(value = "year", required = false) Integer year,
                            @RequestParam(value = "budgetTypeId", required = false) Integer budgetTypeId,
                            @RequestParam(value = "month", required = false) Integer month,
                            @RequestParam(value = "targetCategory", required = false) String targetCategory,
                            @RequestParam(value = "projectName", required = false) String projectName,
                            @RequestParam(value = "submitYear", required = false) Integer submitYear,
                            @RequestParam(value = "submitMonth", required = false) Integer submitMonth,
                            @RequestParam(value = "submitDay", required = false) Integer submitDay,
                            @RequestParam(value = "organizationNamePart1", required = false) String organizationNamePart1,
                            @RequestParam(value = "organizationNamePart2", required = false) String organizationNamePart2,
                            @RequestParam(value = "representativeTitleAndName", required = false) String representativeTitleAndName,
                            @RequestParam(value = "error", required = false) String error,
                            Model model) {
        if (year == null) year = currentFiscalYear();
        LocalDate today = LocalDate.now();

        model.addAttribute("year", year);
        model.addAttribute("years", availableFiscalYears());
        model.addAttribute("budgetTypeId", budgetTypeId);
        model.addAttribute("month", month);
        model.addAttribute("targetCategory", targetCategory);
        model.addAttribute("projectName", projectName);
        model.addAttribute("error", error);
        // プレビュー画面の「条件を編集」から戻ってきた場合は、渡された提出情報をそのまま引き継ぐ（Finding P2対応）
        model.addAttribute("submitYear", submitYear);
        model.addAttribute("submitMonth", submitMonth);
        model.addAttribute("submitDay", submitDay);
        model.addAttribute("organizationNamePart1", organizationNamePart1);
        model.addAttribute("organizationNamePart2", organizationNamePart2);
        model.addAttribute("representativeTitleAndName", representativeTitleAndName);
        model.addAttribute("defaultSubmitYear", today.getYear() - 2018); // 令和年（2019=令和元年基準）
        model.addAttribute("defaultSubmitMonth", today.getMonthValue());
        model.addAttribute("defaultSubmitDay", today.getDayOfMonth());
        model.addAttribute("defaultOrgPart1", "宮崎県アイスホッケー");
        model.addAttribute("defaultOrgPart2", "連盟");
        model.addAttribute("defaultRepresentative", "会長　黒木 誠一郎");
        return "export/year_setup";
    }

    @PostMapping("/year/preview")
    public String yearPreview(@RequestParam("year") int year,
                              @RequestParam(value = "budgetTypeId", required = false) Integer budgetTypeId,
                              @RequestParam(value = "month", required = false) Integer month,
                              @RequestParam(value = "targetCategory", required = false) String targetCategory,
                              @RequestParam(value = "projectName", required = false) String projectName,
                              @RequestParam("submitYear") int submitYear,
                              @RequestParam("submitMonth") int submitMonth,
                              @RequestParam("submitDay") int submitDay,
                              @RequestParam("organizationNamePart1") String organizationNamePart1,
                              @RequestParam("organizationNamePart2") String organizationNamePart2,
                              @RequestParam("representativeTitleAndName") String representativeTitleAndName,
                              Model model) throws Exception {
        List<Project> projects = projectMapper.findFiltered(year, budgetTypeId, month, targetCategory, projectName);
        if (projects.isEmpty()) {
            return "redirect:" + noDataRedirectUrl(year, budgetTypeId, month, targetCategory, projectName,
                    submitYear, submitMonth, submitDay, organizationNamePart1, organizationNamePart2, representativeTitleAndName);
        }
        List<Integer> ids = projects.stream().map(Project::getId).collect(Collectors.toList());

        ExcelExportService.AnnualSubmissionInfo info = buildSubmissionInfo(
                submitYear, submitMonth, submitDay, organizationNamePart1, organizationNamePart2, representativeTitleAndName);
        ExcelExportService.AnnualPreviewData preview = excelExportService.buildAnnualPreview(year, ids, info);

        model.addAttribute("preview", preview);
        model.addAttribute("year", year);
        model.addAttribute("budgetTypeId", budgetTypeId);
        model.addAttribute("month", month);
        model.addAttribute("targetCategory", targetCategory);
        model.addAttribute("projectName", projectName);
        model.addAttribute("submitYear", submitYear);
        model.addAttribute("submitMonth", submitMonth);
        model.addAttribute("submitDay", submitDay);
        model.addAttribute("organizationNamePart1", organizationNamePart1);
        model.addAttribute("organizationNamePart2", organizationNamePart2);
        model.addAttribute("representativeTitleAndName", representativeTitleAndName);
        model.addAttribute("projectCount", ids.size());
        return "export/year_preview";
    }

    @PostMapping("/year/download")
    public void yearDownload(@RequestParam("year") int year,
                             @RequestParam(value = "budgetTypeId", required = false) Integer budgetTypeId,
                             @RequestParam(value = "month", required = false) Integer month,
                             @RequestParam(value = "targetCategory", required = false) String targetCategory,
                             @RequestParam(value = "projectName", required = false) String projectName,
                             @RequestParam("submitYear") int submitYear,
                             @RequestParam("submitMonth") int submitMonth,
                             @RequestParam("submitDay") int submitDay,
                             @RequestParam("organizationNamePart1") String organizationNamePart1,
                             @RequestParam("organizationNamePart2") String organizationNamePart2,
                             @RequestParam("representativeTitleAndName") String representativeTitleAndName,
                             HttpServletResponse response) throws Exception {
        List<Project> projects = projectMapper.findFiltered(year, budgetTypeId, month, targetCategory, projectName);
        if (projects.isEmpty()) {
            response.sendRedirect(noDataRedirectUrl(year, budgetTypeId, month, targetCategory, projectName,
                    submitYear, submitMonth, submitDay, organizationNamePart1, organizationNamePart2, representativeTitleAndName));
            return;
        }
        List<Integer> ids = projects.stream().map(Project::getId).collect(Collectors.toList());

        ExcelExportService.AnnualSubmissionInfo info = buildSubmissionInfo(
                submitYear, submitMonth, submitDay, organizationNamePart1, organizationNamePart2, representativeTitleAndName);

        String fname = year + "年度_年度末決算書類.xlsx";
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setHeader("Content-Disposition",
                "attachment; filename*=UTF-8''" + java.net.URLEncoder.encode(fname, "UTF-8").replace("+", "%20"));
        excelExportService.exportAnnualClosingBook(year, ids, info, response.getOutputStream());
    }

    /**
     * 対象事業0件時のリダイレクト先URL。年度以外の絞り込み条件・提出情報もすべて引き継ぐ
     * （Finding P1/P2対応：条件が意図せず失われないようにする）。
     */
    private String noDataRedirectUrl(int year, Integer budgetTypeId, Integer month, String targetCategory, String projectName,
            int submitYear, int submitMonth, int submitDay,
            String organizationNamePart1, String organizationNamePart2, String representativeTitleAndName) {
        return org.springframework.web.util.UriComponentsBuilder.fromPath("/export/year/setup")
                .queryParam("year", year)
                .queryParamIfPresent("budgetTypeId", java.util.Optional.ofNullable(budgetTypeId))
                .queryParamIfPresent("month", java.util.Optional.ofNullable(month))
                .queryParamIfPresent("targetCategory", java.util.Optional.ofNullable(targetCategory))
                .queryParamIfPresent("projectName", java.util.Optional.ofNullable(projectName))
                .queryParam("submitYear", submitYear)
                .queryParam("submitMonth", submitMonth)
                .queryParam("submitDay", submitDay)
                .queryParam("organizationNamePart1", organizationNamePart1)
                .queryParam("organizationNamePart2", organizationNamePart2)
                .queryParam("representativeTitleAndName", representativeTitleAndName)
                .queryParam("error", "no_data")
                .encode(java.nio.charset.StandardCharsets.UTF_8)
                .build()
                .toUriString();
    }

    private ExcelExportService.AnnualSubmissionInfo buildSubmissionInfo(int submitYear, int submitMonth, int submitDay,
            String organizationNamePart1, String organizationNamePart2, String representativeTitleAndName) {
        ExcelExportService.AnnualSubmissionInfo info = new ExcelExportService.AnnualSubmissionInfo();
        info.setSubmitYear(submitYear);
        info.setSubmitMonth(submitMonth);
        info.setSubmitDay(submitDay);
        info.setOrganizationNamePart1(organizationNamePart1);
        info.setOrganizationNamePart2(organizationNamePart2);
        info.setRepresentativeTitleAndName(representativeTitleAndName);
        return info;
    }

    private int currentFiscalYear() {
        LocalDate now = LocalDate.now();
        return now.getMonthValue() >= 4 ? now.getYear() : now.getYear() - 1;
    }

    private List<Integer> availableFiscalYears() {
        Set<Integer> years = new TreeSet<>(Collections.reverseOrder());
        for (Project p : projectMapper.findAll()) {
            if (p.getEventDate() != null) {
                int y = p.getEventDate().getMonthValue() >= 4 ? p.getEventDate().getYear() : p.getEventDate().getYear() - 1;
                years.add(y);
            }
        }
        years.add(currentFiscalYear());
        return new ArrayList<>(years);
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
