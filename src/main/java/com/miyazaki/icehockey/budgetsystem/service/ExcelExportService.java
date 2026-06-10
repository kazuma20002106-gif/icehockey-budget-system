package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.model.Project;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.io.OutputStream;

@Service
public class ExcelExportService {

    public void exportProjectForms(Project project, OutputStream outputStream) throws Exception {
        // Load the template Excel file
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            // 様式２－４ (Form 2-4)
            var sheet24 = workbook.getSheet("様式２－４①②事業実施・実績報告書（選手強化費）");
            if (sheet24 != null) {
                // Here we would write the project data to specific cells
                // e.g., sheet24.getRow(10).getCell(5).setCellValue(project.getName());
            }

            // 様式２－５ (Form 2-5)
            var sheet25 = workbook.getSheet("様式２－５①事業別参加者名簿（選手強化）");
            if (sheet25 != null) {
                // write participants data
            }

            // 様式２－６ (Form 2-6)
            var sheet26 = workbook.getSheet("様式２－６①事業別領収書１（選手強化）");
            if (sheet26 != null) {
                // write expenses data
            }

            // Write to response output stream
            workbook.write(outputStream);
        }
    }
}
