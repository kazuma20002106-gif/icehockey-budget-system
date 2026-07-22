package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.mapper.BudgetTypeMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.MemberMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.*;
import com.miyazaki.icehockey.budgetsystem.service.ExcelExportService;
import com.miyazaki.icehockey.budgetsystem.service.ProjectService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletResponse;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Controller
@RequestMapping("/activity")
public class ActivityController {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private BudgetTypeMapper budgetTypeMapper;
    @Autowired private MemberMapper memberMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;
    @Autowired private ProjectSummaryExpenseMapper summaryMapper;
    @Autowired private ProjectService projectService;
    @Autowired private ExcelExportService excelExportService;
    @Autowired private com.miyazaki.icehockey.budgetsystem.mapper.RouteMasterMapper routeMasterMapper;

    // ===== 一覧画面 =====
    @GetMapping
    public String list(@RequestParam(value = "year", required = false) Integer year,
                       @RequestParam(value = "budgetTypeId", required = false) Integer budgetTypeId,
                       @RequestParam(value = "month", required = false) Integer month,
                       @RequestParam(value = "targetCategory", required = false) String targetCategory,
                       @RequestParam(value = "projectName", required = false) String projectName,
                       @RequestParam(value = "printedStatus", required = false) String printedStatus,
                       @RequestParam(value = "error", required = false) String error,
                       Model model) {
        // 年度未指定なら現在の会計年度
        if (year == null) year = currentFiscalYear();
        // printedStatus未指定（初回アクセス）は未印刷のみを既定表示にする。ユーザーが明示的に選んだ値はそのまま維持する
        boolean printedStatusDefaulted = (printedStatus == null || printedStatus.isBlank());
        String effectivePrintedStatus = printedStatusDefaulted ? "unprinted" : printedStatus;

        List<Project> projects = projectMapper.findFiltered(year, budgetTypeId, month, targetCategory, projectName, effectivePrintedStatus);

        List<ActivityRow> rows = new ArrayList<>();
        int totalCount = 0, totalParticipants = 0;
        long grandTotal = 0;
        for (Project p : projects) {
            List<ProjectParticipant> parts = participantMapper.findByProjectId(p.getId());
            long expenseTotal = 0;
            for (ProjectParticipant part : parts) {
                List<Expense> exList = expenseMapper.findByProjectParticipantId(part.getId());
                for (Expense e : exList) {
                    // 決算書計上額（様式2-2系）には個人雑費miscellaneousCostを含めない
                    expenseTotal += nz(e.getTransportCost()) + nz(e.getAccommodationCost());
                }
            }
            ProjectSummaryExpense sum = summaryMapper.findByProjectId(p.getId());
            if (sum != null) {
                expenseTotal += nz(sum.getRentalCost()) + nz(sum.getSuppliesCost()) + nz(sum.getParkingCost())
                        + nz(sum.getCompensationCost()) + nz(sum.getServiceCost());
                expenseTotal += nz(sum.getTravelMiscCost()) * parts.size() * nz(sum.getTravelMiscDays());
            }
            ActivityRow row = new ActivityRow();
            row.setProject(p);
            row.setBudgetLabel(budgetLabel(p.getBudgetTypeId()));
            row.setBudgetColor(budgetColor(p.getBudgetTypeId()));
            row.setParticipantCount(parts.size());
            row.setExpenseTotal(expenseTotal);
            rows.add(row);

            totalCount++;
            totalParticipants += parts.size();
            grandTotal += expenseTotal;
        }

        model.addAttribute("rows", rows);
        model.addAttribute("budgetTypes", budgetTypeMapper.findAll());
        model.addAttribute("years", availableFiscalYears());
        model.addAttribute("selectedYear", year);
        model.addAttribute("selectedBudgetTypeId", budgetTypeId);
        model.addAttribute("selectedMonth", month);
        model.addAttribute("selectedTargetCategory", targetCategory);
        model.addAttribute("selectedProjectName", projectName);
        model.addAttribute("selectedPrintedStatus", effectivePrintedStatus);
        model.addAttribute("totalCount", totalCount);
        model.addAttribute("totalParticipants", totalParticipants);
        model.addAttribute("grandTotal", grandTotal);
        model.addAttribute("error", error);
        return "activity/list";
    }

    // ===== 新規入力フォーム =====
    @GetMapping("/new")
    public String newForm(Model model) {
        ActivityForm form = new ActivityForm();
        Project p = new Project();
        p.setLocationAccommodation("宿泊なし");
        form.setProject(p);
        prepareFormModel(model, form, null);
        return "activity/form";
    }

    // ===== 編集フォーム =====
    @GetMapping("/{id}/edit")
    public String editForm(@PathVariable("id") int id,
                           @RequestParam(value = "duplicated", required = false) String duplicated,
                           Model model) {
        Project project = projectMapper.findById(id);
        if (project == null) return "redirect:/activity";

        ActivityForm form = new ActivityForm();
        form.setProject(project);

        ProjectSummaryExpense summary = summaryMapper.findByProjectId(id);
        if (summary == null) {
            summary = new ProjectSummaryExpense();
            summary.setProjectId(id);
        }
        form.setSummary(summary);

        List<ProjectParticipant> participants = participantMapper.findByProjectId(id);
        form.setParticipants(participants);
        for (ProjectParticipant p : participants) {
            List<Expense> ex = expenseMapper.findByProjectParticipantId(p.getId());
            form.getExpenses().add(ex.isEmpty() ? new Expense() : ex.get(0));
        }

        prepareFormModel(model, form, id);
        model.addAttribute("duplicated", duplicated != null);
        return "activity/form";
    }

    // ===== 保存（新規・編集 共通） =====
    @PostMapping("/save")
    public String save(@ModelAttribute("activityForm") ActivityForm form) {
        Project project = form.getProject();
        boolean isNew = (project.getId() == null);
        if (isNew) {
            projectMapper.insert(project);
        } else {
            projectMapper.update(project);
        }
        int id = project.getId();

        ProjectSummaryExpense summary = form.getSummary();
        summary.setProjectId(id);
        projectService.saveProjectData(id, summary, form.getParticipants(), form.getExpenses());

        // 距離データの自動学習（UPSERT）
        if (form.getExpenses() != null) {
            for (Expense e : form.getExpenses()) {
                if (e != null && e.getTransportRoute() != null && e.getTransportDistanceKm() != null && e.getTransportDistanceKm() > 0) {
                    String[] parts = e.getTransportRoute().split("～|〜");
                    if (parts.length >= 2) {
                        RouteMaster rm = new RouteMaster();
                        rm.setDeparture(parts[0].trim());
                        rm.setDestination(parts[parts.length - 1].trim());
                        rm.setDistanceKm(e.getTransportDistanceKm());
                        routeMasterMapper.upsert(rm);
                    }
                }
            }
        }

        return "redirect:/activity?year=" + (project.getFiscalYear() != null ? project.getFiscalYear() : currentFiscalYear());
    }

    // ===== 削除 =====
    @PostMapping("/{id}/delete")
    public String delete(@PathVariable("id") int id) {
        projectMapper.delete(id); // participants/expenses/summary は ON DELETE CASCADE
        return "redirect:/activity";
    }

    // ===== 一括：印刷ステータス変更 =====
    @PostMapping("/bulk/status")
    public String bulkStatus(@RequestParam(value = "projectIds", required = false) List<Integer> projectIds,
                             @RequestParam("isPrinted") boolean isPrinted,
                             @RequestParam(value = "year", required = false) Integer year,
                             @RequestParam(value = "budgetTypeId", required = false) Integer budgetTypeId,
                             @RequestParam(value = "month", required = false) Integer month,
                             @RequestParam(value = "targetCategory", required = false) String targetCategory,
                             @RequestParam(value = "projectName", required = false) String projectName,
                             @RequestParam(value = "printedStatus", required = false) String printedStatus) {
        if (projectIds == null || projectIds.isEmpty()) {
            return "redirect:" + activityRedirectUrl(year, budgetTypeId, month, targetCategory, projectName, printedStatus, "no_selection");
        }
        for (Integer id : projectIds) {
            if (id != null) projectMapper.updatePrinted(id, isPrinted);
        }
        return "redirect:" + activityRedirectUrl(year, budgetTypeId, month, targetCategory, projectName, printedStatus, null);
    }

    // ===== 一括：削除 =====
    @PostMapping("/bulk/delete")
    public String bulkDelete(@RequestParam(value = "projectIds", required = false) List<Integer> projectIds,
                             @RequestParam(value = "year", required = false) Integer year,
                             @RequestParam(value = "budgetTypeId", required = false) Integer budgetTypeId,
                             @RequestParam(value = "month", required = false) Integer month,
                             @RequestParam(value = "targetCategory", required = false) String targetCategory,
                             @RequestParam(value = "projectName", required = false) String projectName,
                             @RequestParam(value = "printedStatus", required = false) String printedStatus) {
        if (projectIds == null || projectIds.isEmpty()) {
            return "redirect:" + activityRedirectUrl(year, budgetTypeId, month, targetCategory, projectName, printedStatus, "no_selection");
        }
        // 存在しないIDが混ざっていても projectMapper.delete は対象0件で正常終了するため500にならない
        for (Integer id : projectIds) {
            if (id != null) projectMapper.delete(id);
        }
        return "redirect:" + activityRedirectUrl(year, budgetTypeId, month, targetCategory, projectName, printedStatus, null);
    }

    // ===== 複製（入力ひな形目的。金額項目はコピーしない） =====
    @PostMapping("/{id}/duplicate")
    public String duplicate(@PathVariable("id") int id) {
        Project source = projectMapper.findById(id);
        if (source == null) return "redirect:/activity";

        List<ProjectParticipant> participants = participantMapper.findByProjectId(id);
        for (ProjectParticipant p : participants) {
            List<Expense> exList = expenseMapper.findByProjectParticipantId(p.getId());
            if (exList.size() > 1) {
                // 1参加者に複数Expenseがある活動は、編集画面が1参加者1Expense前提のため安全のため複製不可とする
                return "redirect:/activity?error=duplicate_multi_expense";
            }
        }

        int newId = projectService.duplicateProject(source, participants);
        return "redirect:/activity/" + newId + "/edit?duplicated=1";
    }

    // ===== 単一活動のExcel出力 =====
    // form=all(既定): 2-4/2-5/2-6 をまとめて1ブック / form=2-4|2-5|2-6: 様式単体
    @GetMapping("/{id}/export")
    public void exportOne(@PathVariable("id") int id,
                          @RequestParam(value = "form", defaultValue = "all") String form,
                          HttpServletResponse response) throws Exception {
        List<Integer> ids = Collections.singletonList(id);
        String fname = "activity_" + id + "_" + form + ".xlsx";
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setHeader("Content-Disposition", "attachment; filename=\"" + fname + "\"");

        java.io.OutputStream out = response.getOutputStream();
        switch (form) {
            case "2-4": excelExportService.exportForm24(ids, out); break;
            case "2-5": excelExportService.exportForm25(ids, out); break;
            case "2-6": excelExportService.exportForm26(ids, out); break;
            default:    excelExportService.exportAllFormsForProjects(ids, out); break;
        }
    }

    // ===== 年度まとめExcel出力（様式2-2決算書＋全活動の2-4/2-5/2-6） =====
    @GetMapping("/export/year")
    public void exportYear(@RequestParam(value = "year", required = false) Integer year,
                           @RequestParam(value = "budgetTypeId", required = false) Integer budgetTypeId,
                           @RequestParam(value = "month", required = false) Integer month,
                           @RequestParam(value = "targetCategory", required = false) String targetCategory,
                           @RequestParam(value = "projectName", required = false) String projectName,
                           HttpServletResponse response) throws Exception {
        if (year == null) year = currentFiscalYear();
        List<Project> projects = projectMapper.findFiltered(year, budgetTypeId, month, targetCategory, projectName, null);
        List<Integer> ids = projects.stream().map(Project::getId).collect(Collectors.toList());

        String fname = year + "年度_まとめ.xlsx";
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setHeader("Content-Disposition",
                "attachment; filename*=UTF-8''" + java.net.URLEncoder.encode(fname, "UTF-8").replace("+", "%20"));
        excelExportService.exportYearlySummary(ids, response.getOutputStream());
    }

    // ===== Cycle 12A: 年度末決算ファイル一括出力（様式2-1/2-2/2-2-1×3＋既存2-4/2-5/2-6） =====
    @GetMapping("/export/annual")
    public void exportAnnual(@RequestParam(value = "year", required = false) Integer year,
                             @RequestParam(value = "budgetTypeId", required = false) Integer budgetTypeId,
                             @RequestParam(value = "month", required = false) Integer month,
                             @RequestParam(value = "targetCategory", required = false) String targetCategory,
                             @RequestParam(value = "projectName", required = false) String projectName,
                             HttpServletResponse response) throws Exception {
        if (year == null) year = currentFiscalYear();
        List<Project> projects = projectMapper.findFiltered(year, budgetTypeId, month, targetCategory, projectName, null);
        if (projects.isEmpty()) {
            // 対象事業0件のまま出力すると、様式2-1の対象年度等が誤った内容になり得るため出力を止める
            response.sendRedirect("/activity?year=" + year + "&error=no_data_for_annual_export");
            return;
        }
        List<Integer> ids = projects.stream().map(Project::getId).collect(Collectors.toList());

        String fname = year + "年度_年度末決算書類.xlsx";
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setHeader("Content-Disposition",
                "attachment; filename*=UTF-8''" + java.net.URLEncoder.encode(fname, "UTF-8").replace("+", "%20"));
        excelExportService.exportAnnualClosingBook(year, ids, response.getOutputStream());
    }

    // ===== ヘルパー =====
    /** 一括処理後、現在の絞り込み条件をできる限り維持したまま /activity へ戻すためのURLを組み立てる */
    private String activityRedirectUrl(Integer year, Integer budgetTypeId, Integer month, String targetCategory,
            String projectName, String printedStatus, String error) {
        return org.springframework.web.util.UriComponentsBuilder.fromPath("/activity")
                .queryParamIfPresent("year", Optional.ofNullable(year))
                .queryParamIfPresent("budgetTypeId", Optional.ofNullable(budgetTypeId))
                .queryParamIfPresent("month", Optional.ofNullable(month))
                .queryParamIfPresent("targetCategory", Optional.ofNullable(targetCategory))
                .queryParamIfPresent("projectName", Optional.ofNullable(projectName))
                .queryParamIfPresent("printedStatus", Optional.ofNullable(printedStatus))
                .queryParamIfPresent("error", Optional.ofNullable(error))
                .encode(java.nio.charset.StandardCharsets.UTF_8)
                .build()
                .toUriString();
    }

    private void prepareFormModel(Model model, ActivityForm form, Integer editId) {
        model.addAttribute("activityForm", form);
        model.addAttribute("budgetTypes", budgetTypeMapper.findAll());
        model.addAttribute("members", memberMapper.findAll());
        model.addAttribute("editId", editId);
    }

    private int currentFiscalYear() {
        LocalDate now = LocalDate.now();
        return now.getMonthValue() >= 4 ? now.getYear() : now.getYear() - 1;
    }

    private List<Integer> availableFiscalYears() {
        Set<Integer> years = new TreeSet<>(Collections.reverseOrder());
        for (Project p : projectMapper.findAll()) {
            if (p.getFiscalYear() != null) years.add(p.getFiscalYear());
        }
        years.add(currentFiscalYear());
        return new ArrayList<>(years);
    }

    private long nz(Integer v) { return v == null ? 0 : v; }

    private String budgetLabel(Integer budgetTypeId) {
        if (budgetTypeId == null) return "未設定";
        switch (budgetTypeId) {
            case 1: return "①選手強化費";
            case 2: return "②トップチーム活用事業";
            case 3: return "③ふるさと選手活動支援";
            default: return "区分" + budgetTypeId;
        }
    }

    private String budgetColor(Integer budgetTypeId) {
        if (budgetTypeId == null) return "secondary";
        switch (budgetTypeId) {
            case 1: return "primary";   // 青
            case 2: return "info";      // 水色
            case 3: return "success";   // 緑
            default: return "secondary";
        }
    }

    // 一覧行DTO
    public static class ActivityRow {
        private Project project;
        private String budgetLabel;
        private String budgetColor;
        private int participantCount;
        private long expenseTotal;

        public Project getProject() { return project; }
        public void setProject(Project project) { this.project = project; }
        public String getBudgetLabel() { return budgetLabel; }
        public void setBudgetLabel(String budgetLabel) { this.budgetLabel = budgetLabel; }
        public String getBudgetColor() { return budgetColor; }
        public void setBudgetColor(String budgetColor) { this.budgetColor = budgetColor; }
        public int getParticipantCount() { return participantCount; }
        public void setParticipantCount(int participantCount) { this.participantCount = participantCount; }
        public long getExpenseTotal() { return expenseTotal; }
        public void setExpenseTotal(long expenseTotal) { this.expenseTotal = expenseTotal; }
    }
}
