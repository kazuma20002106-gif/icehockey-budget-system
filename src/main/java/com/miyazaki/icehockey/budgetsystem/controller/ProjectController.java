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

import java.util.List;

@Controller
@RequestMapping("/projects")
public class ProjectController {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private BudgetTypeMapper budgetTypeMapper;
    @Autowired private MemberMapper memberMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;
    @Autowired private ProjectSummaryExpenseMapper summaryMapper;
    @Autowired private ProjectService projectService;
    @Autowired private ExcelExportService excelExportService;

    @GetMapping
    public String index(Model model) {
        model.addAttribute("projects", projectMapper.findAll());
        model.addAttribute("budgetTypes", budgetTypeMapper.findAll());
        return "projects/index";
    }

    @PostMapping("/add")
    public String add(Project project) {
        projectMapper.insert(project);
        return "redirect:/projects/" + project.getId();
    }

    @GetMapping("/{id}")
    public String detail(@PathVariable("id") int id, Model model) {
        Project project = projectMapper.findById(id);
        if (project == null) return "redirect:/projects";

        model.addAttribute("project", project);
        model.addAttribute("members", memberMapper.findAll());
        
        ProjectForm form = new ProjectForm();
        ProjectSummaryExpense summary = summaryMapper.findByProjectId(id);
        if (summary != null) {
            form.setSummary(summary);
        } else {
            summary = new ProjectSummaryExpense();
            summary.setProjectId(id);
            form.setSummary(summary);
        }

        List<ProjectParticipant> participants = participantMapper.findByProjectId(id);
        form.setParticipants(participants);
        for (ProjectParticipant p : participants) {
            List<Expense> ex = expenseMapper.findByProjectParticipantId(p.getId());
            if (!ex.isEmpty()) {
                form.getExpenses().add(ex.get(0));
            } else {
                form.getExpenses().add(new Expense());
            }
        }
        
        model.addAttribute("form", form);
        return "projects/detail";
    }

    @PostMapping("/{id}/save")
    public String save(@PathVariable("id") int id, @ModelAttribute("form") ProjectForm form) {
        projectService.saveProjectData(id, form.getSummary(), form.getParticipants(), form.getExpenses());
        return "redirect:/projects/" + id;
    }
    
    @GetMapping("/{id}/export")
    public void export(@PathVariable("id") int id, HttpServletResponse response) throws Exception {
        Project project = projectMapper.findById(id);
        ProjectSummaryExpense summary = summaryMapper.findByProjectId(id);
        List<ProjectParticipant> participants = participantMapper.findByProjectId(id);
        
        // Ensure to populate expenses in participants for export logic
        for (ProjectParticipant p : participants) {
            List<Expense> exList = expenseMapper.findByProjectParticipantId(p.getId());
            if (!exList.isEmpty()) p.setExpense(exList.get(0));
        }

        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setHeader("Content-Disposition", "attachment; filename=\"project_" + id + "_export.xlsx\"");
        
        excelExportService.exportProjectForms(project, summary, participants, response.getOutputStream());
    }
}
