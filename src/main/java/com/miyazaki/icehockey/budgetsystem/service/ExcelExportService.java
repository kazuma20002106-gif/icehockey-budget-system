package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.List;

@Service
public class ExcelExportService {

    public void exportProjectForms(Project project, ProjectSummaryExpense summary, List<ProjectParticipant> participants, OutputStream outputStream) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            // 様式２－４ (Form 2-4)
            Sheet sheet24 = workbook.getSheet("様式２－４①②事業実施・実績報告書（選手強化費）");
            if (sheet24 != null) {
                // Approximate cells based on typical formats
                writeSafe(sheet24, 6, 2, project.getName()); // Row 7, Col C
                writeSafe(sheet24, 7, 2, project.getEventDate().toString());
                writeSafe(sheet24, 8, 2, project.getLocationVenue());
            }

            // 様式２－５ (Form 2-5) Participants
            Sheet sheet25 = workbook.getSheet("様式２－５①事業別参加者名簿（選手強化）");
            if (sheet25 != null) {
                writeSafe(sheet25, 3, 2, project.getName());
                int startRow = 8; // Assuming row 9 is where list starts
                for (int i = 0; i < participants.size(); i++) {
                    ProjectParticipant p = participants.get(i);
                    Row row = sheet25.getRow(startRow + i);
                    if (row == null) row = sheet25.createRow(startRow + i);
                    
                    row.createCell(1).setCellValue(p.getMemberName());
                    row.createCell(2).setCellValue(p.getMemberRole());
                    if (p.getExpense() != null) {
                        row.createCell(4).setCellValue(p.getExpense().getTransportCost());
                        row.createCell(5).setCellValue(p.getExpense().getAccommodationCost());
                    }
                }
            }

            // 様式２－２－１ Project Summary
            Sheet sheet22 = workbook.getSheet("様式２－２－１　事業別決算書（選手強化費）");
            if (sheet22 != null && summary != null) {
                writeSafe(sheet22, 10, 4, String.valueOf(summary.getRentalCost()));
                writeSafe(sheet22, 11, 4, String.valueOf(summary.getSuppliesCost()));
                writeSafe(sheet22, 12, 4, String.valueOf(summary.getParkingCost()));
                writeSafe(sheet22, 13, 4, String.valueOf(summary.getCompensationCost()));
                writeSafe(sheet22, 14, 4, String.valueOf(summary.getServiceCost()));
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
