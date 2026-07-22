package com.miyazaki.icehockey.budgetsystem.controller;

import com.miyazaki.icehockey.budgetsystem.mapper.BudgetAllocationMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.BudgetTypeMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.model.BudgetAllocation;
import com.miyazaki.icehockey.budgetsystem.model.BudgetType;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

@Controller
@RequestMapping("/budget-allocations")
public class BudgetAllocationController {

    @Autowired private BudgetAllocationMapper budgetAllocationMapper;
    @Autowired private ProjectMapper projectMapper;
    @Autowired private BudgetTypeMapper budgetTypeMapper;

    // ===== 一覧・入力画面 =====
    @GetMapping
    public String index(@RequestParam(value = "year", required = false) Integer year,
                        @RequestParam(value = "saved", required = false) String saved,
                        @RequestParam(value = "error", required = false) String error,
                        Model model) {
        if (year == null) year = currentFiscalYear();

        Map<Integer, String> typeNames = new HashMap<>();
        for (BudgetType t : budgetTypeMapper.findAll()) {
            typeNames.put(t.getId(), t.getName());
        }

        // その年度に実績として登録済みの (budgetTypeId, targetCategory) 組だけを入力対象にする（Kazumax合意のB案）
        List<Project> projects = projectMapper.findFiltered(year, null, null, null, null, null);
        LinkedHashSet<String> keys = new LinkedHashSet<>();
        for (Project p : projects) {
            Integer bt = p.getBudgetTypeId();
            String cat = p.getTargetCategory();
            if (bt == null || cat == null || cat.isBlank()) continue;
            keys.add(bt + "_" + cat);
        }
        List<String> sortedKeys = new ArrayList<>(keys);
        sortedKeys.sort((k1, k2) -> {
            String[] a = k1.split("_", 2);
            String[] b = k2.split("_", 2);
            int btCompare = Integer.compare(Integer.parseInt(a[0]), Integer.parseInt(b[0]));
            if (btCompare != 0) return btCompare;
            return Integer.compare(categoryOrder(a[1]), categoryOrder(b[1]));
        });

        Map<String, Long> allocatedMap = new HashMap<>();
        for (BudgetAllocation a : budgetAllocationMapper.findByFiscalYear(year)) {
            long amount = a.getAllocatedAmount() == null ? 0L : a.getAllocatedAmount();
            allocatedMap.put(a.getBudgetTypeId() + "_" + a.getTargetCategory(), amount);
        }

        List<AllocationRow> rows = new ArrayList<>();
        for (String key : sortedKeys) {
            String[] parts = key.split("_", 2);
            int bt = Integer.parseInt(parts[0]);
            String cat = parts[1];
            AllocationRow row = new AllocationRow();
            row.setBudgetTypeId(bt);
            row.setBudgetTypeLabel(typeNames.getOrDefault(bt, "区分" + bt));
            row.setTargetCategory(cat);
            row.setAllocatedAmount(allocatedMap.getOrDefault(key, 0L));
            rows.add(row);
        }

        model.addAttribute("rows", rows);
        model.addAttribute("selectedYear", year);
        model.addAttribute("years", availableFiscalYears());
        model.addAttribute("saved", saved != null);
        model.addAttribute("error", error);
        return "budget_allocations/index";
    }

    // ===== 一括保存 =====
    @PostMapping("/save")
    public String save(@RequestParam("year") int year,
                       @RequestParam(value = "budgetTypeIds", required = false) List<Integer> budgetTypeIds,
                       @RequestParam(value = "targetCategories", required = false) List<String> targetCategories,
                       @RequestParam(value = "allocatedAmounts", required = false) List<String> allocatedAmounts) {
        if (budgetTypeIds == null || targetCategories == null || allocatedAmounts == null
                || budgetTypeIds.size() != targetCategories.size() || budgetTypeIds.size() != allocatedAmounts.size()) {
            return "redirect:/budget-allocations?year=" + year + "&error=invalid_input";
        }

        // その年度に実在する (budgetTypeId, targetCategory) の組み合わせのみ保存を許可する
        Set<String> validKeys = new java.util.HashSet<>();
        for (Project p : projectMapper.findFiltered(year, null, null, null, null, null)) {
            Integer bt = p.getBudgetTypeId();
            String cat = p.getTargetCategory();
            if (bt == null || cat == null || cat.isBlank()) continue;
            validKeys.add(bt + "_" + cat);
        }

        for (int i = 0; i < budgetTypeIds.size(); i++) {
            Integer bt = budgetTypeIds.get(i);
            String cat = targetCategories.get(i);
            if (bt == null || cat == null || cat.isBlank() || !validKeys.contains(bt + "_" + cat)) {
                return "redirect:/budget-allocations?year=" + year + "&error=invalid_input";
            }
        }

        for (int i = 0; i < budgetTypeIds.size(); i++) {
            Long amount = parseAmount(allocatedAmounts.get(i));
            if (amount == null) {
                // 不正入力（負数・数値変換不可）は保存せず、同じ画面へエラー付きで戻す
                return "redirect:/budget-allocations?year=" + year + "&error=invalid_amount";
            }
        }

        for (int i = 0; i < budgetTypeIds.size(); i++) {
            BudgetAllocation a = new BudgetAllocation();
            a.setFiscalYear(year);
            a.setBudgetTypeId(budgetTypeIds.get(i));
            a.setTargetCategory(targetCategories.get(i));
            a.setAllocatedAmount(parseAmount(allocatedAmounts.get(i)));
            budgetAllocationMapper.upsert(a);
        }

        return "redirect:/budget-allocations?year=" + year + "&saved=1";
    }

    /** カンマ区切りを除去して数値化。空欄は0円。負数・数値変換不可はnullを返す（保存しない） */
    private Long parseAmount(String raw) {
        if (raw == null || raw.isBlank()) return 0L;
        String cleaned = raw.replace(",", "").trim();
        try {
            long v = Long.parseLong(cleaned);
            return v < 0 ? null : v;
        } catch (NumberFormatException e) {
            return null;
        }
    }

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
            if (p.getEventDate() != null) {
                int y = p.getEventDate().getMonthValue() >= 4 ? p.getEventDate().getYear() : p.getEventDate().getYear() - 1;
                years.add(y);
            }
        }
        years.add(currentFiscalYear());
        return new ArrayList<>(years);
    }

    public static class AllocationRow {
        private int budgetTypeId;
        private String budgetTypeLabel;
        private String targetCategory;
        private long allocatedAmount;

        public int getBudgetTypeId() { return budgetTypeId; }
        public void setBudgetTypeId(int budgetTypeId) { this.budgetTypeId = budgetTypeId; }
        public String getBudgetTypeLabel() { return budgetTypeLabel; }
        public void setBudgetTypeLabel(String budgetTypeLabel) { this.budgetTypeLabel = budgetTypeLabel; }
        public String getTargetCategory() { return targetCategory; }
        public void setTargetCategory(String targetCategory) { this.targetCategory = targetCategory; }
        public long getAllocatedAmount() { return allocatedAmount; }
        public void setAllocatedAmount(long allocatedAmount) { this.allocatedAmount = allocatedAmount; }
    }
}
