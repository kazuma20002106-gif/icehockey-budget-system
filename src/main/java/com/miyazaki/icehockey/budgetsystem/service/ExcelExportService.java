package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

@Service
public class ExcelExportService {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private ProjectSummaryExpenseMapper summaryMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;

    // Helper to get fully loaded participants
    private List<ProjectParticipant> getLoadedParticipants(int projectId) {
        List<ProjectParticipant> participants = participantMapper.findByProjectId(projectId);
        for (ProjectParticipant p : participants) {
            List<Expense> exList = expenseMapper.findByProjectParticipantId(p.getId());
            if (!exList.isEmpty()) p.setExpense(exList.get(0));
        }
        return participants;
    }

    public void exportProjectForms(Project project, ProjectSummaryExpense summary, List<ProjectParticipant> participants, OutputStream outputStream) throws Exception {
        // Fallback for old single export, though now we prefer batch.
        // Left here for compatibility with existing single-export button.
        List<Integer> ids = new ArrayList<>();
        ids.add(project.getId());
        exportForm24(ids, outputStream); // just exports 2-4 as default for single, or we can just keep the old logic.
    }

    public void exportForm24(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("様式２－４①②事業実施・実績報告書（選手強化費）", projectIds, outputStream, (sheet, project, summary, participants) -> {
            writeSafe(sheet, 6, 3, project.getName()); // 事業名 [7,4]
            writeSafe(sheet, 10, 3, project.getTargetCategory()); // 種別 [11,4]
            writeSafe(sheet, 14, 3, project.getEventDate().toString()); // 期日 [15,4]
            writeSafe(sheet, 15, 3, project.getLocationVenue()); // 会場 [16,4]
            writeSafe(sheet, 16, 3, project.getLocationAccommodation()); // 宿舎名 [17,4]

            if (summary != null) {
                writeSafeNumeric(sheet, 23, 3, summary.getParkingCost()); // 駐車料 [24,4]
                writeSafeNumeric(sheet, 24, 3, summary.getRentalCost()); // 借用料 [25,4]
                writeSafeNumeric(sheet, 25, 3, summary.getSuppliesCost()); // 需用費 [26,4]
                writeSafeNumeric(sheet, 26, 3, summary.getServiceCost()); // 役務費 [27,4]
                writeSafeNumeric(sheet, 27, 3, summary.getCompensationCost()); // その他（報償費）[28,4]
            }

            int transportSum = 0;
            int accommodationSum = 0;
            int coachCount = 0;
            int playerCount = 0;

            for (ProjectParticipant p : participants) {
                if ("指導者".equals(p.getMemberRole())) coachCount++;
                else playerCount++;

                if (p.getExpense() != null) {
                    transportSum += p.getExpense().getTransportCost();
                    accommodationSum += p.getExpense().getAccommodationCost();
                }
            }

            writeSafeNumeric(sheet, 20, 3, transportSum); // 交通費 [21,4]
            writeSafeNumeric(sheet, 21, 3, accommodationSum); // 宿泊費 [22,4]
            writeSafeNumeric(sheet, 17, 3, coachCount); // 指導者数
            writeSafeNumeric(sheet, 17, 6, playerCount); // 選手数
        });
    }

    public void exportForm25(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("様式２－５①事業別参加者名簿（選手強化）", projectIds, outputStream, (sheet, project, summary, participants) -> {
            writeSafe(sheet, 5, 2, project.getEventDate().toString()); // 実施日 [6,3]
            
            int startRow = 8; // Row 9
            for (int i = 0; i < participants.size(); i++) {
                ProjectParticipant p = participants.get(i);
                writeSafe(sheet, startRow + i, 1, p.getMemberRole()); // 監督・選手 [row, 2]
                writeSafe(sheet, startRow + i, 3, p.getMemberName()); // 氏名 [row, 4]
                // writeSafe(sheet, startRow + i, 6, String.valueOf(p.getMemberAge())); // 年齢 [row, 7]
                writeSafe(sheet, startRow + i, 7, p.getIsAccommodated() ? "〇" : ""); // 宿泊 [row, 8]
            }
        });
    }

    public void exportForm26(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("様式２－６①事業別領収書１（選手強化）", projectIds, outputStream, (sheet, project, summary, participants) -> {
            int startRow = 9; // Row 10 is participant 1
            for (int i = 0; i < participants.size(); i++) {
                ProjectParticipant p = participants.get(i);
                int r = startRow + (i * 3);
                writeSafe(sheet, r, 2, p.getMemberName()); // 氏名 [r, 3]
                writeSafe(sheet, r, 9, project.getEventDate().toString()); // 期日 [r, 10]
                
                if (p.getExpense() != null) {
                    writeSafe(sheet, r, 13, p.getExpense().getTransportMethod()); // 交通手段 [r, 14]
                    writeSafeNumeric(sheet, r + 1, 13, p.getExpense().getTransportCost()); // 費用 [r+1, 14]
                }
            }
        });
    }

    public void exportForm22Summary(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            String templateName = "様式２－２－１　事業別決算書（選手強化費）";
            Sheet sheet22 = workbook.getSheet(templateName);

            if (sheet22 != null) {
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
                    List<ProjectParticipant> parts = getLoadedParticipants(id);
                    for (ProjectParticipant p : parts) {
                        if (p.getExpense() != null) {
                            totalTransport += p.getExpense().getTransportCost();
                            totalAccommodation += p.getExpense().getAccommodationCost();
                        }
                    }
                }

                writeSafeNumeric(sheet22, 15, 9, totalTransport); // 交通費 [16,10]
                writeSafeNumeric(sheet22, 17, 9, totalAccommodation); // 宿泊費 [18,10]
                writeSafeNumeric(sheet22, 21, 9, totalParking); // 駐車料 [22,10]
                writeSafeNumeric(sheet22, 23, 9, totalRental); // 借用料 [24,10]
                writeSafeNumeric(sheet22, 25, 9, totalCompensation); // 報償費 [26,10]
                writeSafeNumeric(sheet22, 27, 9, totalSupplies); // 需用費 [28,10]
                writeSafeNumeric(sheet22, 29, 9, totalService); // 役務費 [30,10]
            }

            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                if (!workbook.getSheetName(i).equals(templateName)) {
                    workbook.removeSheetAt(i);
                }
            }

            workbook.write(outputStream);
        }
    }

    private interface SheetPopulator {
        void populate(Sheet sheet, Project project, ProjectSummaryExpense summary, List<ProjectParticipant> participants);
    }

    private void exportMultiSheet(String templateName, List<Integer> projectIds, OutputStream outputStream, SheetPopulator populator) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            int templateIndex = workbook.getSheetIndex(templateName);
            if (templateIndex == -1) throw new IllegalArgumentException("Template sheet not found: " + templateName);

            for (int id : projectIds) {
                Project project = projectMapper.findById(id);
                ProjectSummaryExpense summary = summaryMapper.findByProjectId(id);
                List<ProjectParticipant> participants = getLoadedParticipants(id);

                Sheet newSheet = workbook.cloneSheet(templateIndex);
                String safeName = project.getName().replaceAll("[\\\\/?*:\\[\\]]", "_");
                if (safeName.length() > 20) safeName = safeName.substring(0, 20);
                String finalName = safeName + "_" + id;
                workbook.setSheetName(workbook.getSheetIndex(newSheet), finalName);

                populator.populate(newSheet, project, summary, participants);
            }

            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                String sName = workbook.getSheetName(i);
                if (!sName.matches(".*_\\d+$")) {
                    workbook.removeSheetAt(i);
                }
            }

            workbook.write(outputStream);
        }
    }

    private void writeSafe(Sheet sheet, int rowIndex, int colIndex, String value) {
        if (value == null) return;
        Row row = sheet.getRow(rowIndex);
        if (row == null) row = sheet.createRow(rowIndex);
        org.apache.poi.ss.usermodel.Cell cell = row.getCell(colIndex);
        if (cell == null) cell = row.createCell(colIndex);
        cell.setCellValue(value);
    }

    private void writeSafeNumeric(Sheet sheet, int rowIndex, int colIndex, int value) {
        Row row = sheet.getRow(rowIndex);
        if (row == null) row = sheet.createRow(rowIndex);
        org.apache.poi.ss.usermodel.Cell cell = row.getCell(colIndex);
        if (cell == null) cell = row.createCell(colIndex);
        cell.setCellValue(value);
    }
}
