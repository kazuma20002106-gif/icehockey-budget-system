package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.mapper.BudgetAllocationMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.BudgetTypeMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.BudgetAllocation;
import com.miyazaki.icehockey.budgetsystem.model.BudgetType;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

// Cycle 17: トップ画面。年度の状況（活動数・印刷ステータス・決算書計上額・予算使用状況）をざっくり確認する
@Controller
public class DashboardController {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;
    @Autowired private ProjectSummaryExpenseMapper summaryMapper;
    @Autowired private BudgetAllocationMapper budgetAllocationMapper;
    @Autowired private BudgetTypeMapper budgetTypeMapper;

    @GetMapping("/dashboard")
    public String dashboard(@RequestParam(value = "year", required = false) Integer year, Model model) {
        if (year == null) year = currentFiscalYear();

        // 印刷ステータスに関わらず年度内の全活動を対象にする（"all"）
        List<Project> projects = projectMapper.findFiltered(year, null, null, null, null, "all");

        int totalCount = 0, printedCount = 0, unprintedCount = 0;
        long grandTotal = 0;
        Map<String, Long> usedMap = new HashMap<>();

        for (Project p : projects) {
            totalCount++;
            if (Boolean.TRUE.equals(p.getIsPrinted())) printedCount++; else unprintedCount++;

            List<ProjectParticipant> parts = participantMapper.findByProjectId(p.getId());
            long expenseTotal = 0;
            for (ProjectParticipant part : parts) {
                for (Expense e : expenseMapper.findByProjectParticipantId(part.getId())) {
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
            grandTotal += expenseTotal;

            Integer bt = p.getBudgetTypeId();
            String cat = p.getTargetCategory();
            if (bt != null && cat != null && !cat.isBlank()) {
                String key = bt + "_" + cat;
                usedMap.merge(key, expenseTotal, Long::sum);
            }
        }

        Map<Integer, String> typeNames = new HashMap<>();
        for (BudgetType t : budgetTypeMapper.findAll()) {
            typeNames.put(t.getId(), t.getName());
        }

        Map<String, Long> allocatedMap = new HashMap<>();
        for (BudgetAllocation a : budgetAllocationMapper.findByFiscalYear(year)) {
            long amount = a.getAllocatedAmount() == null ? 0L : a.getAllocatedAmount();
            allocatedMap.put(a.getBudgetTypeId() + "_" + a.getTargetCategory(), amount);
        }

        // 予算登録がある組み合わせ・活動実績がある組み合わせの両方を表示対象にする
        LinkedHashSet<String> keys = new LinkedHashSet<>();
        keys.addAll(usedMap.keySet());
        keys.addAll(allocatedMap.keySet());
        List<String> sortedKeys = new ArrayList<>(keys);
        sortedKeys.sort((k1, k2) -> {
            String[] a = k1.split("_", 2);
            String[] b = k2.split("_", 2);
            int btCompare = Integer.compare(Integer.parseInt(a[0]), Integer.parseInt(b[0]));
            if (btCompare != 0) return btCompare;
            return Integer.compare(categoryOrder(a[1]), categoryOrder(b[1]));
        });

        List<BudgetUsageRow> budgetRows = new ArrayList<>();
        for (String key : sortedKeys) {
            String[] parts = key.split("_", 2);
            int bt = Integer.parseInt(parts[0]);
            String cat = parts[1];
            long used = usedMap.getOrDefault(key, 0L);
            long allocated = allocatedMap.getOrDefault(key, 0L);

            BudgetUsageRow row = new BudgetUsageRow();
            row.setBudgetTypeLabel(typeNames.getOrDefault(bt, "区分" + bt));
            row.setTargetCategory(cat);
            row.setUsedAmount(used);
            row.setAllocatedAmount(allocated);
            row.setRemainingAmount(allocated - used);
            // allocated=0 は0除算を避けるため使用率なし（画面側で "-" 表示）
            row.setUsageRate(allocated == 0 ? null : (used * 100.0 / allocated));
            budgetRows.add(row);
        }

        model.addAttribute("year", year);
        model.addAttribute("years", availableFiscalYears());
        model.addAttribute("totalCount", totalCount);
        model.addAttribute("printedCount", printedCount);
        model.addAttribute("unprintedCount", unprintedCount);
        model.addAttribute("grandTotal", grandTotal);
        model.addAttribute("budgetRows", budgetRows);
        return "dashboard/index";
    }

    private long nz(Integer v) { return v == null ? 0 : v; }

    private int categoryOrder(String category) {
        if (category == null) return 99;
        switch (category) {
            case "成年男子": return 1;
            case "成年女子": return 2;
            case "少年男子": return 3;
            case "少年女子": return 4;
            default: return 5;
        }
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

    public static class BudgetUsageRow {
        private String budgetTypeLabel;
        private String targetCategory;
        private long usedAmount;
        private long allocatedAmount;
        private long remainingAmount;
        private Double usageRate; // null = allocated 0円（使用率なし）

        public String getBudgetTypeLabel() { return budgetTypeLabel; }
        public void setBudgetTypeLabel(String budgetTypeLabel) { this.budgetTypeLabel = budgetTypeLabel; }
        public String getTargetCategory() { return targetCategory; }
        public void setTargetCategory(String targetCategory) { this.targetCategory = targetCategory; }
        public long getUsedAmount() { return usedAmount; }
        public void setUsedAmount(long usedAmount) { this.usedAmount = usedAmount; }
        public long getAllocatedAmount() { return allocatedAmount; }
        public void setAllocatedAmount(long allocatedAmount) { this.allocatedAmount = allocatedAmount; }
        public long getRemainingAmount() { return remainingAmount; }
        public void setRemainingAmount(long remainingAmount) { this.remainingAmount = remainingAmount; }
        public Double getUsageRate() { return usageRate; }
        public void setUsageRate(Double usageRate) { this.usageRate = usageRate; }
    }
}
