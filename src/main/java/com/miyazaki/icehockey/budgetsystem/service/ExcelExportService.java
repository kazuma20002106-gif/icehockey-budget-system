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
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            String templateName = "様式２－４①②事業実施・実績報告書（選手強化費）";
            int templateIndex = workbook.getSheetIndex(templateName);
            if (templateIndex == -1) throw new IllegalArgumentException("Template sheet not found: " + templateName);

            for (int i = 0; i < projectIds.size(); i += 2) {
                int id1 = projectIds.get(i);
                Integer id2 = (i + 1 < projectIds.size()) ? projectIds.get(i + 1) : null;

                Sheet newSheet = workbook.cloneSheet(templateIndex);
                workbook.setSheetName(workbook.getSheetIndex(newSheet), "2-4_" + id1 + (id2 != null ? "_" + id2 : ""));

                populate24Side(newSheet, id1, 0); // Left side
                if (id2 != null) {
                    populate24Side(newSheet, id2, 17); // Right side
                } else {
                    // Optionally clear out the right side if it's empty, but we can leave it blank for now.
                }
            }

            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                String sName = workbook.getSheetName(i);
                if (!sName.startsWith("2-4_")) {
                    workbook.removeSheetAt(i);
                }
            }

            workbook.write(outputStream);
        }
    }

    private void populate24Side(Sheet sheet, int projectId, int colOffset) {
        Project project = projectMapper.findById(projectId);
        ProjectSummaryExpense summary = summaryMapper.findByProjectId(projectId);
        List<ProjectParticipant> participants = getLoadedParticipants(projectId);

        // Draw ellipse for Project Name
        if ("強化練習".equals(project.getName())) {
            drawEllipse(sheet, 6, 4 + colOffset, 7, 9 + colOffset);
        } else if ("遠征試合".equals(project.getName())) {
            drawEllipse(sheet, 6, 12 + colOffset, 7, 17 + colOffset);
        }

        // Draw ellipse for Category
        if ("成年男子".equals(project.getTargetCategory())) {
            drawEllipse(sheet, 10, 4 + colOffset, 11, 8 + colOffset);
        } else if ("成年女子".equals(project.getTargetCategory())) {
            drawEllipse(sheet, 10, 12 + colOffset, 11, 16 + colOffset);
        } else if ("少年男子".equals(project.getTargetCategory())) {
            drawEllipse(sheet, 11, 4 + colOffset, 12, 8 + colOffset);
        } else if ("少年女子".equals(project.getTargetCategory())) {
            drawEllipse(sheet, 11, 12 + colOffset, 12, 16 + colOffset);
        }

        writeSafe(sheet, 14, 3 + colOffset, project.getEventDate().toString()); // 期日 [15,4]
        writeSafe(sheet, 15, 3 + colOffset, project.getLocationVenue()); // 会場 [16,4]
        writeSafe(sheet, 16, 3 + colOffset, project.getLocationAccommodation()); // 宿舎名 [17,4]
        writeSafe(sheet, 34, 3 + colOffset, project.getScheduleContent()); // 日程及び内容 [D35]
        writeSafe(sheet, 40, 3 + colOffset, project.getProjectOutcome()); // 事業の成果 [D41]

        if (summary != null) {
            writeSafeNumeric(sheet, 23, 3 + colOffset, summary.getParkingCost()); // 駐車料 [24,4]
            writeSafeNumeric(sheet, 24, 3 + colOffset, summary.getRentalCost()); // 借用料 [25,4]
            writeSafeNumeric(sheet, 25, 3 + colOffset, summary.getSuppliesCost()); // 需用費 [26,4]
            writeSafeNumeric(sheet, 26, 3 + colOffset, summary.getServiceCost()); // 役務費 [27,4]
            writeSafeNumeric(sheet, 27, 3 + colOffset, summary.getCompensationCost()); // その他（報償費）[28,4]
        }

        int transportSum = 0;
        int accommodationSum = 0;
        int miscSum = 0;
        int coachCount = 0;
        int playerCount = 0;

        for (ProjectParticipant p : participants) {
            if ("指導者".equals(p.getMemberRole())) coachCount++;
            else playerCount++;

            if (p.getExpense() != null) {
                transportSum += nz(p.getExpense().getTransportCost());
                accommodationSum += nz(p.getExpense().getAccommodationCost());
                miscSum += nz(p.getExpense().getMiscellaneousCost());
            }
        }

        writeSafeNumeric(sheet, 20, 3 + colOffset, transportSum); // 交通費 [21,4]
        writeSafeNumeric(sheet, 21, 3 + colOffset, accommodationSum); // 宿泊費 [22,4]
        writeSafeNumeric(sheet, 22, 3 + colOffset, miscSum); // 旅行雑費 [D23]

        if (colOffset == 0) {
            writeSafeNumeric(sheet, 17, 6, coachCount); // 指導者数
            writeSafeNumeric(sheet, 17, 12, playerCount); // 選手数
        } else {
            writeSafeNumeric(sheet, 17, 23, coachCount);
            writeSafeNumeric(sheet, 17, 29, playerCount);
        }
    }

    private void drawEllipse(Sheet sheet, int row1, int col1, int row2, int col2) {
        if (sheet instanceof org.apache.poi.xssf.usermodel.XSSFSheet) {
            org.apache.poi.xssf.usermodel.XSSFSheet xssfSheet = (org.apache.poi.xssf.usermodel.XSSFSheet) sheet;
            org.apache.poi.xssf.usermodel.XSSFDrawing drawing = xssfSheet.createDrawingPatriarch();
            org.apache.poi.xssf.usermodel.XSSFClientAnchor anchor = drawing.createAnchor(0, 0, 0, 0, col1, row1, col2, row2);
            org.apache.poi.xssf.usermodel.XSSFSimpleShape shape = drawing.createSimpleShape(anchor);
            shape.setShapeType(org.apache.poi.ss.usermodel.ShapeTypes.ELLIPSE);
            shape.setLineStyleColor(0, 0, 0); // Black
            shape.setLineWidth(1.5);
            shape.setNoFill(true);
        }
    }

    public void exportForm25(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("様式２－５①事業別参加者名簿（選手強化）", projectIds, outputStream,
                (sheet, project, summary, participants) -> populate25(sheet, project, participants));
    }

    // 2-5 は指導者・選手すべてを出力する
    private void populate25(Sheet sheet, Project project, List<ProjectParticipant> participants) {
        if (project.getEventDate() != null) {
            writeSafe(sheet, 5, 2, project.getEventDate().toString()); // 実施日 [6,3]
        }
        int startRow = 8;   // 番号1の行
        int lastRow = 35;   // 番号28の行（テンプレートの参加者欄の最終）
        for (int i = 0; i < participants.size(); i++) {
            ProjectParticipant p = participants.get(i);
            int r = startRow + i;
            writeSafe(sheet, r, 1, p.getMemberRole()); // 監督・選手別 [B]
            writeSafe(sheet, r, 3, p.getMemberName()); // 氏名 [D]
            if (p.getMemberAge() != null) writeSafeNumeric(sheet, r, 6, p.getMemberAge()); // 年齢 [G]
            else clearCell(sheet, r, 6);
            writeSafe(sheet, r, 7, p.getIsAccommodated() ? "〇" : ""); // 宿泊 [H]
        }
        // テンプレートのダミー（参加者数以降の行）をクリア
        for (int r = startRow + participants.size(); r <= lastRow; r++) {
            clearCell(sheet, r, 1);
            clearCell(sheet, r, 3);
            clearCell(sheet, r, 6);
            clearCell(sheet, r, 7);
        }
    }

    public void exportForm26(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("様式２－６①事業別領収書１（選手強化）", projectIds, outputStream,
                (sheet, project, summary, participants) -> populate26(sheet, project, participants));
    }

    private void populate26(Sheet sheet, Project project, List<ProjectParticipant> allParticipants) {
        // Overwrite title in R2C15 based on category
        String title = "選手強化費　　領収書１";
        if ("トップチーム".equals(project.getName())) {
            title = "トップチーム選手強化事業　領収書１";
        } else if ("ふるさと".equals(project.getName())) {
            title = "ふるさと選手強化事業　領収書１";
        }
        writeSafe(sheet, 1, 15, title);

        // 【変更】2-6 は選手・指導者関係なく、交通費か宿泊費が1円以上の人のみ反映
        List<ProjectParticipant> validParticipants = new ArrayList<>();
        for (ProjectParticipant p : allParticipants) {
            int tCost = (p.getExpense() != null) ? nz(p.getExpense().getTransportCost()) : 0;
            int aCost = (p.getExpense() != null) ? nz(p.getExpense().getAccommodationCost()) : 0;
            int mCost = (p.getExpense() != null) ? nz(p.getExpense().getMiscellaneousCost()) : 0;
            
            if (tCost + aCost + mCost > 0) {
                validParticipants.add(p);
            }
        }

        final int startRow = 9; // No.1 の先頭行
        final int block = 3;    // 1人=3行
        final int maxSlots = 8; // テンプレートは No.1〜8

        for (int i = 0; i < validParticipants.size() && i < maxSlots; i++) {
            ProjectParticipant p = validParticipants.get(i);
            int r = startRow + (i * block);
            Expense e = p.getExpense();

            writeSafe(sheet, r, 2, p.getMemberName()); // 氏名 [C]
            writeSafe(sheet, r, 9, (e != null && e.getExpenseDate() != null) ? e.getExpenseDate().toString() : ""); // 期日 [J]

            // 交通: 1行目に交通手段（距離付き）、3行目に区間を出力。2行目はクリア。
            String method = (e != null) ? e.getTransportMethod() : null;
            Integer distKm = (e != null) ? e.getTransportDistanceKm() : null;

            clearCell(sheet, r, 13);       // 1行目クリア
            clearCell(sheet, r + 1, 13);   // 2行目クリア
            writeSafe(sheet, r, 13, buildTransportLabel(method, distKm));                                            // 1行目: 交通手段
            writeSafe(sheet, r + 2, 13, (e != null && e.getTransportRoute() != null) ? e.getTransportRoute() : ""); // 3行目: 区間

            // 支払額はブロック先頭行
            writeSafeNumeric(sheet, r, 19, (e != null) ? nz(e.getTransportCost()) : 0);     // 交通費 [T]
            writeSafeNumeric(sheet, r, 23, (e != null) ? nz(e.getAccommodationCost()) : 0);  // 宿泊費 [X]
            writeSafe(sheet, r, 27, "-");  // 雑費 [AB] は今後全て「-」表示
            String receiptDateStr = "";
            if (e != null && e.getReceiptDate() != null) {
                receiptDateStr = e.getReceiptDate().toString();
            } else if (project.getEventDate() != null) {
                receiptDateStr = project.getEventDate().toString();
            }
            writeSafe(sheet, r, 31, receiptDateStr); // 受領日 [AF]
        }

        // 参加者数以降の余り行（テンプレートのダミー）をクリア
        for (int i = validParticipants.size(); i < maxSlots; i++) {
            int r = startRow + (i * block);
            clearCell(sheet, r, 2);       // 氏名
            clearCell(sheet, r, 9);       // 期日
            clearCell(sheet, r, 13);      // 交通1行目
            clearCell(sheet, r + 1, 13);  // 交通2行目
            clearCell(sheet, r + 2, 13);  // 交通3行目
            clearCell(sheet, r, 19);      // 交通費
            clearCell(sheet, r, 23);      // 宿泊費
            clearCell(sheet, r, 27);      // 雑費
            clearCell(sheet, r, 31);      // 受領日
        }
    }

    public void exportForm22Summary(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            String templateName = SHEET_22;
            Sheet sheet22 = workbook.getSheet(templateName);
            if (sheet22 != null) {
                populate22Summary(sheet22, projectIds);
            }

            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                if (!workbook.getSheetName(i).equals(templateName)) {
                    workbook.removeSheetAt(i);
                }
            }

            workbook.write(outputStream);
        }
    }

    // 様式2-2決算書に年間合算を書き込む
    private void populate22Summary(Sheet sheet22, List<Integer> projectIds) {
        int totalRental = 0, totalSupplies = 0, totalParking = 0, totalCompensation = 0, totalService = 0;
        int totalTransport = 0, totalAccommodation = 0;

        for (int id : projectIds) {
            ProjectSummaryExpense sum = summaryMapper.findByProjectId(id);
            if (sum != null) {
                totalRental += nz(sum.getRentalCost());
                totalSupplies += nz(sum.getSuppliesCost());
                totalParking += nz(sum.getParkingCost());
                totalCompensation += nz(sum.getCompensationCost());
                totalService += nz(sum.getServiceCost());
            }
            List<ProjectParticipant> parts = getLoadedParticipants(id);
            for (ProjectParticipant p : parts) {
                if (p.getExpense() != null) {
                    totalTransport += nz(p.getExpense().getTransportCost());
                    totalAccommodation += nz(p.getExpense().getAccommodationCost());
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

    // ===== テンプレートシート名 =====
    private static final String SHEET_24 = "様式２－４①②事業実施・実績報告書（選手強化費）";
    private static final String SHEET_25 = "様式２－５①事業別参加者名簿（選手強化）";
    private static final String SHEET_26 = "様式２－６①事業別領収書１（選手強化）";
    private static final String SHEET_22 = "様式２－２－１　事業別決算書（選手強化費）";

    /** 1つ以上の活動について、様式2-4/2-5/2-6 を1ブックにまとめて出力。 */
    public void exportAllFormsForProjects(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        buildCombinedWorkbook(projectIds, false, outputStream);
    }

    /** 年度まとめ：様式2-2決算書（合算）＋ 全活動の 2-4/2-5/2-6 を1ブックにまとめて出力。 */
    public void exportYearlySummary(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        buildCombinedWorkbook(projectIds, true, outputStream);
    }

    private void buildCombinedWorkbook(List<Integer> projectIds, boolean includeSummary22, OutputStream outputStream) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            int idx24 = workbook.getSheetIndex(SHEET_24);
            int idx25 = workbook.getSheetIndex(SHEET_25);
            int idx26 = workbook.getSheetIndex(SHEET_26);

            // 様式2-2（年度まとめ時のみ、テンプレートのまま合算を書き込んで残す）
            if (includeSummary22) {
                Sheet sheet22 = workbook.getSheet(SHEET_22);
                if (sheet22 != null) populate22Summary(sheet22, projectIds);
            }

            // 様式2-4：2活動ずつ左右に配置
            if (idx24 != -1) {
                for (int i = 0; i < projectIds.size(); i += 2) {
                    int id1 = projectIds.get(i);
                    Integer id2 = (i + 1 < projectIds.size()) ? projectIds.get(i + 1) : null;
                    Sheet s = workbook.cloneSheet(idx24);
                    workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, "2-4_" + id1));
                    populate24Side(s, id1, 0);
                    if (id2 != null) populate24Side(s, id2, 17);
                }
            }

            // 様式2-5 / 2-6：活動ごとに1シート
            for (int id : projectIds) {
                Project project = projectMapper.findById(id);
                List<ProjectParticipant> participants = getLoadedParticipants(id);
                if (idx25 != -1) {
                    Sheet s = workbook.cloneSheet(idx25);
                    workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, "2-5_" + id));
                    populate25(s, project, participants);
                }
                if (idx26 != -1) {
                    Sheet s = workbook.cloneSheet(idx26);
                    workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, "2-6_" + id));
                    populate26(s, project, participants);
                }
            }

            // 生成シート以外（テンプレート原本）を削除。年度まとめ時は2-2を残す。
            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                String name = workbook.getSheetName(i);
                boolean generated = name.startsWith("2-4_") || name.startsWith("2-5_") || name.startsWith("2-6_");
                boolean keepSummary = includeSummary22 && name.equals(SHEET_22);
                if (!generated && !keepSummary) {
                    workbook.removeSheetAt(i);
                }
            }

            // 最低1シートは必要
            if (workbook.getNumberOfSheets() == 0) {
                workbook.createSheet("データなし");
            }

            workbook.write(outputStream);
        }
    }

    private String uniqueName(Workbook wb, String base) {
        if (base.length() > 28) base = base.substring(0, 28);
        String name = base;
        int n = 1;
        while (wb.getSheetIndex(name) != -1) {
            name = base + "_" + (n++);
        }
        return name;
    }

    private int nz(Integer v) { return v == null ? 0 : v; }

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

    // セルの文字列を取得（無ければnull）
    private String getCellString(Sheet sheet, int rowIndex, int colIndex) {
        Row row = sheet.getRow(rowIndex);
        if (row == null) return null;
        org.apache.poi.ss.usermodel.Cell cell = row.getCell(colIndex);
        if (cell == null) return null;
        if (cell.getCellType() == org.apache.poi.ss.usermodel.CellType.STRING) return cell.getStringCellValue();
        return null;
    }

    // セルの値を空白化（書式は維持）
    private void clearCell(Sheet sheet, int rowIndex, int colIndex) {
        Row row = sheet.getRow(rowIndex);
        if (row == null) return;
        org.apache.poi.ss.usermodel.Cell cell = row.getCell(colIndex);
        if (cell == null) return;
        cell.setBlank();
    }

    // 交通手段表示文字列を組み立てる
    private String buildTransportLabel(String method, Integer distKm) {
        if (method == null || method.isEmpty()) return "";
        switch (method) {
            case "航空機": return "航空機";
            case "バス":   return "バス";
            case "電車": {
                String d = (distKm != null) ? String.valueOf(distKm) : "    ";
                return "電車( " + d + " )㎞";
            }
            case "自家用車": {
                String d = (distKm != null) ? String.valueOf(distKm) : "    ";
                return "自家用車( " + d + " )㎞";
            }
            default: return method;
        }
    }

    // ラベルが空のときだけ補完（既存テキストは消さない）
    private void ensureLabel(Sheet sheet, int rowIndex, int colIndex, String label) {
        String cur = getCellString(sheet, rowIndex, colIndex);
        if (cur == null || cur.trim().isEmpty()) writeSafe(sheet, rowIndex, colIndex, label);
    }
}
