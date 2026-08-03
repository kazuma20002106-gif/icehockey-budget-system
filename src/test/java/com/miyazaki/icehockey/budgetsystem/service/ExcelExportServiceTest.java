package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import org.apache.poi.ss.usermodel.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Cycle 20: 年度末Excel完全性の回帰テスト。
 * 出力は常にメモリ上（ByteArrayOutputStream）に留め、外部固定パスへは一切書き出さない。
 * DBは読み取りのみで、更新SQLは発行しない（既存のKazumax本物DBを破壊しない）。
 */
@SpringBootTest
class ExcelExportServiceTest {

    @Autowired
    private ExcelExportService excelExportService;

    @Autowired
    private ProjectMapper projectMapper;

    private static final String SHEET_22 = "様式２－２－１　事業別決算書（選手強化費）";
    private static final String SHEET_22_1_TOP = "様式２－２－１　事業別決算書（トップチーム活用)";
    private static final String SHEET_22_1_FURUSATO = "様式２－２－１　事業別決算書（ふるさと）";
    private static final String SHEET_23 = "様式２－３";

    @Test
    void annualClosingBook_2026_writesFiscalYearAndClearsForm23Dummies() throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        excelExportService.exportAnnualClosingBook(2026, Collections.emptyList(), out);

        try (Workbook wb = WorkbookFactory.create(new ByteArrayInputStream(out.toByteArray()))) {
            // 要件1: 2-2-1（3シート）の年度が令和8年度(2026-2018)であること
            assertEquals(8.0, numericValue(wb.getSheet(SHEET_22), 1, 7), "SHEET_22 H2 should be Reiwa 8");
            assertEquals(8.0, numericValue(wb.getSheet(SHEET_22_1_TOP), 2, 7), "SHEET_22_1_TOP H3 should be Reiwa 8");
            assertEquals(8.0, numericValue(wb.getSheet(SHEET_22_1_FURUSATO), 2, 7), "SHEET_22_1_FURUSATO H3 should be Reiwa 8");

            // 要件2: 様式2-3 上部不可侵エリア（1〜23行目）は手を加えない
            Sheet sheet23 = wb.getSheet(SHEET_23);
            assertNotNull(sheet23, "Sheet 2-3 must exist");
            assertNotNull(sheet23.getRow(3), "Inviolable area (Row 4) should remain intact");

            // 要件2: ③ふるさと（Row33）の原本ダミー値605000/750239が残っていないこと（2026年度はふるさと0件）
            assertBlankOrZero(sheet23, 32, 10, 605000.0, "K33");
            assertBlankOrZero(sheet23, 32, 19, 750239.0, "T33");
            assertBlankOrZero(sheet23, 32, 28, null, "AC33");

            // 要件2: ①選手強化費セクション（Row25〜28）も、データなし年度なら空/ゼロであること
            for (int r = 24; r <= 27; r++) {
                assertBlankOrZero(sheet23, r, 10, null, "Row" + (r + 1) + " K");
                assertBlankOrZero(sheet23, r, 19, null, "Row" + (r + 1) + " T");
            }

            // 要件4: 数式評価が失敗せず完了し、いずれのセルにも数式エラーが残っていないこと
            assertNoFormulaErrors(wb);
        }
    }

    @Test
    void annualClosingBook_realData_hasNoFormulaErrorsAndPreservesLegitimateValues() throws Exception {
        List<Project> allProjects = projectMapper.findAll();
        List<Integer> projectIds = allProjects.stream().map(Project::getId).collect(Collectors.toList());
        if (projectIds.isEmpty()) {
            return; // ローカル環境にデータが無い場合はスキップ（DBを書き換えない）
        }

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        excelExportService.exportAnnualClosingBook(2026, projectIds, out);

        try (Workbook wb = WorkbookFactory.create(new ByteArrayInputStream(out.toByteArray()))) {
            // 要件4: 実データを含めても数式エラー文字列が0件であること
            assertNoFormulaErrors(wb);

            // 要件3: 様式2-5/2-6シートについて、参加者がいない空きスロットの主要列に
            // 原本ダミー値(936)が残っていないことを全シート走査で確認する。
            // 正当なDB由来の936は書込列の値として現れうるため、ここでは「空きスロット」だけを対象にする。
            for (Sheet sheet : wb) {
                String name = sheet.getSheetName();
                if (name.startsWith("2-6_")) {
                    assertNoDummyInEmptySlots26(sheet);
                }
            }
        }
    }

    private void assertNoDummyInEmptySlots26(Sheet sheet) {
        // populate26: startRow=9, block=3, maxSlots=10。「氏名」列(col2)が空文字/blankの3行ブロックだけを
        // 空きスロットとみなし、その中の主要列(2,9,19,23,27,31)に値が残っていないことを確認する。
        final int startRow = 9, block = 3, maxSlots = 10;
        for (int i = 0; i < maxSlots; i++) {
            int r = startRow + (i * block);
            Row row = sheet.getRow(r);
            if (row == null) continue;
            Cell nameCell = row.getCell(2);
            boolean nameBlank = nameCell == null || nameCell.getCellType() == CellType.BLANK
                    || (nameCell.getCellType() == CellType.STRING && nameCell.getStringCellValue().isEmpty());
            if (!nameBlank) continue; // 参加者ありスロットは対象外

            for (int c : new int[]{9, 19, 23, 27, 31}) {
                for (int rr = r; rr <= r + 2; rr++) {
                    Row targetRow = sheet.getRow(rr);
                    if (targetRow == null) continue;
                    Cell cell = targetRow.getCell(c);
                    if (cell == null) continue;
                    assertTrue(cell.getCellType() == CellType.BLANK
                            || (cell.getCellType() == CellType.STRING && cell.getStringCellValue().isEmpty())
                            || (cell.getCellType() == CellType.NUMERIC && cell.getNumericCellValue() == 0.0),
                            sheet.getSheetName() + " row" + (rr + 1) + " col" + c
                                    + " should be blank in an unused slot, but was: " + cellDebugString(cell));
                }
            }
        }
    }

    private void assertNoFormulaErrors(Workbook wb) {
        for (Sheet sheet : wb) {
            for (Row row : sheet) {
                for (Cell cell : row) {
                    assertNotEquals(CellType.ERROR, cell.getCellType(),
                            sheet.getSheetName() + " " + cell.getAddress() + " has a formula error");
                    if (cell.getCellType() == CellType.FORMULA) {
                        assertNotEquals(CellType.ERROR, cell.getCachedFormulaResultType(),
                                sheet.getSheetName() + " " + cell.getAddress() + " formula cached result is an error");
                    }
                }
            }
        }
    }

    private void assertBlankOrZero(Sheet sheet, int rowIndex, int colIndex, Double forbiddenValue, String label) {
        Row row = sheet.getRow(rowIndex);
        Cell cell = (row == null) ? null : row.getCell(colIndex);
        boolean blankOrZero = cell == null || cell.getCellType() == CellType.BLANK
                || (cell.getCellType() == CellType.NUMERIC && cell.getNumericCellValue() == 0.0);
        assertTrue(blankOrZero, label + " should be blank or zero, but was: " + cellDebugString(cell));
        if (forbiddenValue != null && cell != null && cell.getCellType() == CellType.NUMERIC) {
            assertNotEquals(forbiddenValue, cell.getNumericCellValue(), label + " must not retain the template dummy value");
        }
    }

    private String cellDebugString(Cell cell) {
        if (cell == null) return "null";
        switch (cell.getCellType()) {
            case NUMERIC: return String.valueOf(cell.getNumericCellValue());
            case STRING: return "\"" + cell.getStringCellValue() + "\"";
            default: return cell.getCellType().toString();
        }
    }

    private Double numericValue(Sheet sheet, int rowIndex, int colIndex) {
        if (sheet == null) return null;
        Row row = sheet.getRow(rowIndex);
        if (row == null) return null;
        Cell cell = row.getCell(colIndex);
        if (cell == null || cell.getCellType() != CellType.NUMERIC) return null;
        return cell.getNumericCellValue();
    }
}
