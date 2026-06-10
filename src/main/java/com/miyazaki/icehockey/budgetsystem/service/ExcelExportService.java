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
            writeSafe(sheet, 6, 2, project.getName());
            writeSafe(sheet, 7, 2, project.getEventDate().toString());
            writeSafe(sheet, 8, 2, project.getLocationVenue());
            // More fields as needed
        });
    }

    public void exportForm25(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("様式２－５①事業別参加者名簿（選手強化）", projectIds, outputStream, (sheet, project, summary, participants) -> {
            writeSafe(sheet, 3, 2, project.getName());
            int startRow = 8;
            for (int i = 0; i < participants.size(); i++) {
                ProjectParticipant p = participants.get(i);
                Row row = sheet.getRow(startRow + i);
                if (row == null) row = sheet.createRow(startRow + i);
                row.createCell(1).setCellValue(p.getMemberName());
                row.createCell(2).setCellValue(p.getMemberRole());
                if (p.getExpense() != null) {
                    row.createCell(4).setCellValue(p.getExpense().getTransportCost());
                    row.createCell(5).setCellValue(p.getExpense().getAccommodationCost());
                }
            }
        });
    }

    public void exportForm26(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("様式２－６①事業別領収書１（選手強化）", projectIds, outputStream, (sheet, project, summary, participants) -> {
            writeSafe(sheet, 2, 2, project.getName());
            // Sample logic for receipts
        });
    }

    public void exportForm22Summary(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            String templateName = "様式２－２－１　事業別決算書（選手強化費）";
            Sheet sheet22 = workbook.getSheet(templateName);

            if (sheet22 != null) {
                // Aggregate sums
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

                writeSafe(sheet22, 10, 4, String.valueOf(totalRental));
                writeSafe(sheet22, 11, 4, String.valueOf(totalSupplies));
                writeSafe(sheet22, 12, 4, String.valueOf(totalParking));
                writeSafe(sheet22, 13, 4, String.valueOf(totalCompensation));
                writeSafe(sheet22, 14, 4, String.valueOf(totalService));
                writeSafe(sheet22, 15, 4, String.valueOf(totalTransport + totalAccommodation)); // Example aggregated value
            }

            // Remove all sheets EXCEPT 2-2
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

            // Remove all original template sheets and unused sheets
            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                String sName = workbook.getSheetName(i);
                // If it's one of the original sheets (not ending with _id), remove it
                // We cloned sheets with name "project_name_id". Original sheets don't have this.
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
}
