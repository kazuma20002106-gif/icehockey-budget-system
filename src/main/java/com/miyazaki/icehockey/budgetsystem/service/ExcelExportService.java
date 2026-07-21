package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.BudgetAllocationMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.BudgetAllocation;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import com.miyazaki.icehockey.budgetsystem.model.User;
import com.miyazaki.icehockey.budgetsystem.service.UserSettingService;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.VerticalAlignment;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.io.OutputStream;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class ExcelExportService {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private ProjectSummaryExpenseMapper summaryMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;
    @Autowired private UserSettingService userSettingService;
    @Autowired private BudgetAllocationMapper budgetAllocationMapper;

    // ===== 令和変換・日付 helper =====

    private int getReiwaYear(int year) {
        return year - 2018;
    }

    private String formatJapaneseDate(LocalDate date) {
        if (date == null) return "";
        return "令和" + getReiwaYear(date.getYear()) + "年" + date.getMonthValue() + "月" + date.getDayOfMonth() + "日";
    }

    private String formatJapaneseDateWithWeekday(LocalDate date) {
        if (date == null) return "";
        String[] weekdays = {"日", "月", "火", "水", "木", "金", "土"};
        String w = weekdays[date.getDayOfWeek().getValue() % 7];
        return formatJapaneseDate(date) + "(" + w + ")";
    }

    private String formatMonthDay(LocalDate date) {
        if (date == null) return "";
        return date.getMonthValue() + "/" + date.getDayOfMonth();
    }

    // Helper to get fully loaded participants
    private List<ProjectParticipant> getLoadedParticipants(int projectId) {
        List<ProjectParticipant> participants = participantMapper.findByProjectId(projectId);
        for (ProjectParticipant p : participants) {
            List<Expense> exList = expenseMapper.findByProjectParticipantId(p.getId());
            if (!exList.isEmpty()) p.setExpense(exList.get(0));
        }
        return participants;
    }

    // 様式2-4の右/左の一方をクリアする（空欄表示用）
    private void clearSide24(Sheet sheet, int colOffset) {
        clearCell(sheet, 14, 3 + colOffset);  // 期日
        clearCell(sheet, 15, 3 + colOffset);  // 会場
        clearCell(sheet, 16, 3 + colOffset);  // 宿舎名
        clearCell(sheet, 17, 6 + (colOffset > 0 ? 17 : 0)); // 指導者数 (R18C7/R18C24)
        clearCell(sheet, 17, 12 + (colOffset > 0 ? 17 : 0)); // 選手数 (R18C13/R18C30)
        for (int r = 20; r <= 27; r++) {
            clearCell(sheet, r, 3 + colOffset); // 交通費〜報償費
        }
        clearCell(sheet, 33, 3 + colOffset);  // 計
        clearCell(sheet, 34, 3 + colOffset);  // 日程及び内容
        clearCell(sheet, 40, 3 + colOffset);  // 事業の成果

        // 計算内訳セルを colOffset 対応列でクリア（populate24Side と同じ式）
        // LEFT(colOffset=0): 8/13/17列, RIGHT(colOffset=17): 25/30/34列
        int rateCol  = 8  + colOffset;
        int countCol = 13 + colOffset;
        int daysCol  = 17 + colOffset;
        clearCell(sheet, 21, rateCol);   // 宿泊費単価
        clearCell(sheet, 21, countCol);  // 宿泊対象人数
        clearCell(sheet, 21, daysCol);   // 宿泊泊数
        clearCell(sheet, 22, rateCol);   // 旅行雑費単価
        clearCell(sheet, 22, countCol);  // 旅行雑費人数
        clearCell(sheet, 22, daysCol);   // 旅行雑費日数

        // 右側専用: テンプレート由来の参加人員ダミーデータを追加クリア
        if (colOffset > 0) {
            clearCell(sheet, 18, 17); // R19: 参加人員ダミー値 3
            clearCell(sheet, 18, 19); // T19: 名
            clearCell(sheet, 18, 34); // 参加人員 計の式 (R19C35)
        }
    }

    public void exportProjectForms(Project project, ProjectSummaryExpense summary, List<ProjectParticipant> participants, OutputStream outputStream) throws Exception {
        List<Integer> ids = new ArrayList<>();
        ids.add(project.getId());
        exportForm24(ids, outputStream);
    }

    public void exportForm24(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            int templateIndex = workbook.getSheetIndex(SHEET_24);
            if (templateIndex == -1) throw new IllegalArgumentException("Template sheet not found: " + SHEET_24);

            if (projectIds.size() == 1) {
                // 単独出力: 常に左=対象、右=空欄
                int id = projectIds.get(0);
                Project p = projectMapper.findById(id);
                String btLabel = budgetTypeLabel(p != null ? p.getBudgetTypeId() : null);
                String cat = (p != null && p.getTargetCategory() != null) ? p.getTargetCategory() : "";
                Sheet newSheet = workbook.cloneSheet(templateIndex);
                String nm = sanitizeSheetName("2-4_" + btLabel + "_" + cat + "_" + circledNumber(1));
                workbook.setSheetName(workbook.getSheetIndex(newSheet), uniqueName(workbook, nm));
                populate24Side(newSheet, id, 0);
                pruneTemplateEllipses24Side(newSheet, 0, p);
                clearSide24(newSheet, 17);
                pruneTemplateEllipses24Side(newSheet, 17, null);
            } else {
                // ソート・グループ化を buildCombinedWorkbook と同じルールで適用
                List<Project> sorted24 = new ArrayList<>();
                for (int id : projectIds) {
                    Project p = projectMapper.findById(id);
                    if (p != null) sorted24.add(p);
                }
                sorted24.sort(Comparator
                    .comparingInt((Project p) -> p.getBudgetTypeId() == null ? 99 : p.getBudgetTypeId())
                    .thenComparingInt((Project p) -> categoryOrder(p.getTargetCategory()))
                    .thenComparing((Project p) -> p.getEventDate() == null ? LocalDate.of(9999, 12, 31) : p.getEventDate())
                    .thenComparingInt((Project p) -> p.getId() == null ? Integer.MAX_VALUE : p.getId()));

                Map<String, List<Project>> groups24 = new LinkedHashMap<>();
                for (Project p : sorted24) {
                    String key = (p.getBudgetTypeId() == null ? "0" : p.getBudgetTypeId())
                            + "_" + (p.getTargetCategory() == null ? "" : p.getTargetCategory());
                    groups24.computeIfAbsent(key, k -> new ArrayList<>()).add(p);
                }
                for (Map.Entry<String, List<Project>> entry : groups24.entrySet()) {
                    List<Project> gList = entry.getValue();
                    String btLabel = budgetTypeLabel(gList.get(0).getBudgetTypeId());
                    String cat = gList.get(0).getTargetCategory() == null ? "" : gList.get(0).getTargetCategory();
                    for (int i = 0, sheetNum = 1; i < gList.size(); i += 2, sheetNum++) {
                        Project left = gList.get(i);
                        Project right = (i + 1 < gList.size()) ? gList.get(i + 1) : null;
                        Sheet newSheet = workbook.cloneSheet(templateIndex);
                        String nm = sanitizeSheetName("2-4_" + btLabel + "_" + cat + "_" + circledNumber(sheetNum));
                        workbook.setSheetName(workbook.getSheetIndex(newSheet), uniqueName(workbook, nm));
                        populate24Side(newSheet, left.getId(), 0);
                        pruneTemplateEllipses24Side(newSheet, 0, left);
                        if (right != null) {
                            populate24Side(newSheet, right.getId(), 17);
                            pruneTemplateEllipses24Side(newSheet, 17, right);
                        } else {
                            clearSide24(newSheet, 17);
                            pruneTemplateEllipses24Side(newSheet, 17, null);
                        }
                    }
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

        // 年度 (R2C1, 0-based row=1 col=0) - 両側で同じなので毎回書いて問題なし
        if (project.getEventDate() != null) {
            int rYear = getReiwaYear(project.getFiscalYear() != null
                    ? project.getFiscalYear() : project.getEventDate().getYear());
            Integer btId = project.getBudgetTypeId();
            String budgetPart = (btId != null && btId >= 1 && btId <= 3)
                    ? circledNumber(btId) + budgetTypeLabel(btId)
                    : budgetTypeLabel(btId);
            writeSafe(sheet, 1, 0, "令和" + rYear + "年度　国スポ選手強化プロジェクト（" + budgetPart + "）事業実施報告書");
        }

        // 期日: 令和X年Y月Z日(曜) 形式
        writeSafe(sheet, 14, 3 + colOffset, formatJapaneseDateWithWeekday(project.getEventDate()));
        writeSafe(sheet, 15, 3 + colOffset, project.getLocationVenue());
        writeSafe(sheet, 16, 3 + colOffset, project.getLocationAccommodation());
        writeSafe(sheet, 34, 3 + colOffset, project.getScheduleContent());
        writeSafe(sheet, 40, 3 + colOffset, project.getProjectOutcome());

        int parkingCost = 0, rentalCost = 0, suppliesCost = 0, serviceCost = 0, compensationCost = 0;
        if (summary != null) {
            parkingCost = nz(summary.getParkingCost());
            rentalCost = nz(summary.getRentalCost());
            suppliesCost = nz(summary.getSuppliesCost());
            serviceCost = nz(summary.getServiceCost());
            compensationCost = nz(summary.getCompensationCost());
            writeSafeNumeric(sheet, 23, 3 + colOffset, parkingCost);
            writeSafeNumeric(sheet, 24, 3 + colOffset, rentalCost);
            writeSafeNumeric(sheet, 25, 3 + colOffset, suppliesCost);
            writeSafeNumeric(sheet, 26, 3 + colOffset, serviceCost);
            writeSafeNumeric(sheet, 27, 3 + colOffset, compensationCost);
        }

        int transportSum = 0;
        int accommodationSum = 0;
        int coachCount = 0;
        int playerCount = 0;
        int accommodatedCount = 0;

        for (ProjectParticipant p : participants) {
            if ("指導者".equals(p.getMemberRole())) coachCount++;
            else playerCount++;

            if (p.getIsAccommodated()) accommodatedCount++;

            if (p.getExpense() != null) {
                transportSum += nz(p.getExpense().getTransportCost());
                accommodationSum += nz(p.getExpense().getAccommodationCost());
            }
        }

        int travelMiscCostVal = (summary != null) ? nz(summary.getTravelMiscCost()) : 0;
        int travelMiscDaysVal = (summary != null) ? nz(summary.getTravelMiscDays()) : 0;
        int travelMiscTotal = travelMiscCostVal * (coachCount + playerCount) * travelMiscDaysVal;

        int accNights = (project.getAccommodationNights() != null && project.getAccommodationNights() > 0)
                ? project.getAccommodationNights() : (accommodationSum > 0 ? 1 : 0);
        // 宿泊費単価を保存済み費用から逆算（accommodatedCount > 0 かつ泊数 > 0 の場合）
        int accRate = (accommodatedCount > 0 && accNights > 0)
                ? accommodationSum / accommodatedCount / accNights : 0;

        writeSafeNumeric(sheet, 20, 3 + colOffset, transportSum);
        writeSafeNumeric(sheet, 21, 3 + colOffset, accommodationSum);
        writeSafeNumeric(sheet, 22, 3 + colOffset, travelMiscTotal);

        if (colOffset == 0) {
            writeSafeNumeric(sheet, 17, 6, coachCount);
            writeSafeNumeric(sheet, 17, 12, playerCount);
        } else {
            writeSafeNumeric(sheet, 17, 23, coachCount);
            writeSafeNumeric(sheet, 17, 29, playerCount);
        }

        // 旅行雑費・宿泊費の計算内訳を左右それぞれのセルへ書く
        // LEFT(colOffset=0):  単価→col8(I), 人数→col13(N), 日数/泊数→col17(R)
        // RIGHT(colOffset=17): 単価→col25(Z), 人数→col30(AE), 日数/泊数→col34(AI)
        int rateCol  = 8  + colOffset;
        int countCol = 13 + colOffset;
        int daysCol  = 17 + colOffset;
        // 旅行雑費の計算内訳
        writeSafeNumeric(sheet, 22, rateCol,  travelMiscCostVal);
        writeSafeNumeric(sheet, 22, countCol, coachCount + playerCount);
        writeSafeNumeric(sheet, 22, daysCol,  travelMiscDaysVal);
        // 宿泊費の計算内訳
        writeSafeNumeric(sheet, 21, rateCol,  accRate);
        writeSafeNumeric(sheet, 21, countCol, accommodatedCount);
        writeSafeNumeric(sheet, 21, daysCol,  accNights);

        // 合計金額の強制上書き (R34C4 or R34C21, 0-based row=33)
        int total = transportSum + accommodationSum + travelMiscTotal
                + parkingCost + rentalCost + suppliesCost + serviceCost + compensationCost;
        writeSafeNumeric(sheet, 33, 3 + colOffset, total);

        // 記入責任者氏名・電話番号 (row=46, col=0 - 両側で共有)
        try {
            User activeUser = userSettingService.getActiveUser();
            if (activeUser != null) {
                String responsible = "記入責任者氏名（　" + activeUser.getName()
                        + "　）　　電話番号（　" + activeUser.getFormattedPhoneNumber() + "　）";
                writeSafe(sheet, 46, 0, responsible);
            }
        } catch (Exception e) {
            // ユーザー取得失敗時は空欄のまま
        }
    }

    public void exportForm25(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("2-5", SHEET_25, projectIds, outputStream,
                (sheet, project, summary, participants) -> populate25(sheet, project, participants));
    }

    private void populate25(Sheet sheet, Project project, List<ProjectParticipant> participants) {
        // 年度数値 (R3C3, 0-based row=2 col=2)
        if (project.getEventDate() != null) {
            int fy = project.getFiscalYear() != null ? project.getFiscalYear() : project.getEventDate().getYear();
            writeSafeNumeric(sheet, 2, 2, getReiwaYear(fy));
        }

        // 宿泊あり判定: 画面の「宿泊あり」チェックを基準にする
        boolean hasAccommodation = participants.stream().anyMatch(p -> p.getIsAccommodated());

        int accommodationNights = (project.getAccommodationNights() != null && project.getAccommodationNights() > 0)
                ? project.getAccommodationNights() : (hasAccommodation ? 1 : 0);
        int nightCols = Math.min(accommodationNights, 3);

        // 事業実施日: 令和X年Y月Z日 / 宿泊あり: ～W日 (R6C3, 0-based row=5 col=2)
        if (project.getEventDate() != null) {
            String eventDateText = formatJapaneseDate(project.getEventDate());
            if (hasAccommodation && accommodationNights > 0) {
                LocalDate endDate = project.getEventDate().plusDays(accommodationNights);
                if (endDate.getMonthValue() == project.getEventDate().getMonthValue()) {
                    eventDateText += "～" + endDate.getDayOfMonth() + "日";
                } else {
                    eventDateText += "～" + endDate.getMonthValue() + "月" + endDate.getDayOfMonth() + "日";
                }
            }
            writeSafe(sheet, 5, 2, eventDateText);
        }

        // 宿泊対象者ヘッダー（最大3泊分）。未使用列はクリア
        for (int n = 0; n < 3; n++) {
            if (n < nightCols && hasAccommodation && project.getEventDate() != null) {
                LocalDate stayDate = project.getEventDate().plusDays(n);
                writeSafe(sheet, 7, 7 + n, stayDate.getMonthValue() + "月" + stayDate.getDayOfMonth() + "日");
            } else {
                clearCell(sheet, 7, 7 + n);
            }
        }

        int startRow = 8;
        int lastRow = 35;
        for (int i = 0; i < participants.size(); i++) {
            ProjectParticipant p = participants.get(i);
            int r = startRow + i;
            writeSafe(sheet, r, 1, p.getMemberRole());
            writeSafe(sheet, r, 3, p.getMemberName());
            if (p.getMemberAge() != null) writeSafeNumeric(sheet, r, 6, p.getMemberAge());
            else clearCell(sheet, r, 6);
            // 宿泊チェック済み参加者に〇（各泊分の列へ）
            boolean accommodated = p.getIsAccommodated();
            for (int n = 0; n < nightCols; n++) {
                writeSafe(sheet, r, 7 + n, accommodated ? "〇" : "");
            }
            for (int n = nightCols; n < 3; n++) {
                clearCell(sheet, r, 7 + n);
            }
        }
        for (int r = startRow + participants.size(); r <= lastRow; r++) {
            clearCell(sheet, r, 1);
            clearCell(sheet, r, 3);
            clearCell(sheet, r, 6);
            for (int n = 0; n < 3; n++) clearCell(sheet, r, 7 + n);
        }

        // 記入責任者氏名・電話番号 (R37C1, 0-based row=36 col=0)
        try {
            User activeUser = userSettingService.getActiveUser();
            if (activeUser != null) {
                String line = "記入責任者氏名（　" + activeUser.getName()
                        + "　）　電話番号（　" + activeUser.getFormattedPhoneNumber() + "　）";
                writeSafe(sheet, 36, 0, line);
            } else {
                writeSafe(sheet, 36, 0, "");
            }
        } catch (Exception e) {
            // ignore
        }
    }

    public void exportForm26(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet("2-6", SHEET_26, projectIds, outputStream,
                (sheet, project, summary, participants) -> populate26(sheet, project, participants));
    }

    private void populate26(Sheet sheet, Project project, List<ProjectParticipant> allParticipants) {
        // 年度数値 (R3C10, 0-based row=2 col=9)
        if (project.getEventDate() != null) {
            int fy = project.getFiscalYear() != null ? project.getFiscalYear() : project.getEventDate().getYear();
            writeSafeNumeric(sheet, 2, 9, getReiwaYear(fy));
        }

        // タイトル: budgetTypeId ベースで決定（project.getName() による補助金区分判定は使わない）
        String title = budgetTypeLabel(project.getBudgetTypeId()) + "　　領収書１";
        writeSafe(sheet, 1, 15, title);

        // 2-6 は交通費か宿泊費か雑費が1円以上の人のみ
        List<ProjectParticipant> validParticipants = new ArrayList<>();
        for (ProjectParticipant p : allParticipants) {
            int tCost = (p.getExpense() != null) ? nz(p.getExpense().getTransportCost()) : 0;
            int aCost = (p.getExpense() != null) ? nz(p.getExpense().getAccommodationCost()) : 0;
            int mCost = (p.getExpense() != null) ? nz(p.getExpense().getMiscellaneousCost()) : 0;
            if (tCost + aCost + mCost > 0) {
                validParticipants.add(p);
            }
        }

        final int startRow = 9;
        final int block = 3;
        final int maxSlots = 10;

        int totalTransport = 0, totalAccommodation = 0, totalMisc = 0;

        for (int i = 0; i < validParticipants.size() && i < maxSlots; i++) {
            ProjectParticipant p = validParticipants.get(i);
            int r = startRow + (i * block);
            Expense e = p.getExpense();

            writeSafe(sheet, r, 2, p.getMemberName());

            // 期日: M/d 形式
            LocalDate expDate = (e != null && e.getExpenseDate() != null)
                    ? e.getExpenseDate()
                    : project.getEventDate();
            writeSafe(sheet, r, 9, formatMonthDay(expDate));

            String method = (e != null) ? e.getTransportMethod() : null;
            Integer distKm = (e != null) ? e.getTransportDistanceKm() : null;

            String route = (e != null && e.getTransportRoute() != null) ? e.getTransportRoute() : "";
            // 交通手段を上段、区間を下段に分割表示（N:S x 上2行=手段、下1行=区間）
            writeSplitTransportText(sheet, r, buildMethodLabel(method, distKm), route);

            int tc = (e != null) ? nz(e.getTransportCost()) : 0;
            int ac = (e != null) ? nz(e.getAccommodationCost()) : 0;
            int mc = (e != null) ? nz(e.getMiscellaneousCost()) : 0;

            writeSafeNumeric(sheet, r, 19, tc);
            writeSafeNumeric(sheet, r, 23, ac);
            writeSafeNumeric(sheet, r, 27, mc);

            totalTransport += tc;
            totalAccommodation += ac;
            totalMisc += mc;

            // 受領日: M/d 形式
            LocalDate receiptDate = (e != null && e.getReceiptDate() != null)
                    ? e.getReceiptDate()
                    : project.getEventDate();
            writeSafe(sheet, r, 31, formatMonthDay(receiptDate));
        }

        // 余り行のクリア (交通欄も3行結合に統一して空文字で上書き)
        for (int i = validParticipants.size(); i < maxSlots; i++) {
            int r = startRow + (i * block);
            clearCell(sheet, r, 2);
            clearCell(sheet, r, 9);
            writeSplitTransportText(sheet, r, "", "");
            clearCell(sheet, r, 19);
            clearCell(sheet, r, 23);
            clearCell(sheet, r, 27);
            clearCell(sheet, r, 31);
        }

        // 合計金額の強制上書き (R40, 0-based row=39)
        writeSafeNumeric(sheet, 39, 19, totalTransport);
        writeSafeNumeric(sheet, 39, 23, totalAccommodation);
        writeSafeNumeric(sheet, 39, 27, totalMisc);
        writeSafeNumeric(sheet, 39, 37, totalTransport + totalAccommodation + totalMisc);

        // 作成者名 (R7C29, 0-based row=6 col=28)
        // 記入責任者氏名 (R41C1, 0-based row=40 col=0) と 電話番号 (R41C28, 0-based row=40 col=27)
        try {
            User activeUser = userSettingService.getActiveUser();
            if (activeUser != null) {
                writeSafe(sheet, 6, 28, "作成者名（　" + activeUser.getName() + "　　）");
                writeSafe(sheet, 40, 0, "記入責任者氏名(　" + activeUser.getName() + "　　)");
                writeSafe(sheet, 40, 27, "電話番号(" + activeUser.getFormattedPhoneNumber() + "　)");
            } else {
                writeSafe(sheet, 6, 28, "作成者名（　　）");
                writeSafe(sheet, 40, 0, "記入責任者氏名(　　)");
                writeSafe(sheet, 40, 27, "電話番号(　)");
            }
        } catch (Exception e) {
            // ignore
        }
    }

    public void exportForm22Summary(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            Sheet sheet22 = workbook.getSheet(SHEET_22);
            if (sheet22 != null) {
                populate22Summary(sheet22, projectIds);
            }

            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                if (!workbook.getSheetName(i).equals(SHEET_22)) {
                    workbook.removeSheetAt(i);
                }
            }

            workbook.write(outputStream);
        }
    }

    private void populate22Summary(Sheet sheet22, List<Integer> projectIds) {
        long[] catRental = new long[4];
        long[] catSupplies = new long[4];
        long[] catParking = new long[4];
        long[] catCompensation = new long[4];
        long[] catService = new long[4];
        long[] catTravelMisc = new long[4];
        long[] catTransport = new long[4];
        long[] catAccommodation = new long[4];

        long totalRental = 0, totalSupplies = 0, totalParking = 0, totalCompensation = 0, totalService = 0;
        long totalTransport = 0, totalAccommodation = 0, totalTravelMisc = 0;

        for (int id : projectIds) {
            Project p = projectMapper.findById(id);
            if (p == null) continue;

            String cat = p.getTargetCategory();
            int catIdx = -1;
            if ("成年男子".equals(cat)) catIdx = 0;
            else if ("少年男子".equals(cat)) catIdx = 1;
            else if ("成年女子".equals(cat)) catIdx = 2;
            else if ("少年女子".equals(cat)) catIdx = 3;

            ProjectSummaryExpense sum = summaryMapper.findByProjectId(id);
            List<ProjectParticipant> parts = getLoadedParticipants(id);

            long pRental = 0, pSupplies = 0, pParking = 0, pComp = 0, pServ = 0, pTravelMisc = 0;
            if (sum != null) {
                pRental = nz(sum.getRentalCost());
                pSupplies = nz(sum.getSuppliesCost());
                pParking = nz(sum.getParkingCost());
                pComp = nz(sum.getCompensationCost());
                pServ = nz(sum.getServiceCost());
                pTravelMisc = (long) nz(sum.getTravelMiscCost()) * parts.size() * nz(sum.getTravelMiscDays());
            }

            long pTrans = 0, pAccom = 0;
            for (ProjectParticipant part : parts) {
                if (part.getExpense() != null) {
                    pTrans += nz(part.getExpense().getTransportCost());
                    pAccom += nz(part.getExpense().getAccommodationCost());
                }
            }

            totalRental += pRental;
            totalSupplies += pSupplies;
            totalParking += pParking;
            totalCompensation += pComp;
            totalService += pServ;
            totalTravelMisc += pTravelMisc;
            totalTransport += pTrans;
            totalAccommodation += pAccom;

            if (catIdx >= 0) {
                catRental[catIdx] += pRental;
                catSupplies[catIdx] += pSupplies;
                catParking[catIdx] += pParking;
                catCompensation[catIdx] += pComp;
                catService[catIdx] += pServ;
                catTravelMisc[catIdx] += pTravelMisc;
                catTransport[catIdx] += pTrans;
                catAccommodation[catIdx] += pAccom;
            }
        }

        // 年度 (R2C8, 0-based row=1 col=7) - 先頭プロジェクトから令和年度を計算
        if (!projectIds.isEmpty()) {
            Project first = projectMapper.findById(projectIds.get(0));
            if (first != null && first.getEventDate() != null) {
                int fy = first.getFiscalYear() != null ? first.getFiscalYear() : first.getEventDate().getYear();
                writeSafeNumeric(sheet22, 1, 7, getReiwaYear(fy));
            }
        }

        // 1. ダミー数値をクリア (Rows 15,17,19,21,23,25,27,29 とその+1行の Cols 18, 31 をクリア)
        int[] itemRows = {15, 17, 19, 21, 23, 25, 27, 29};
        for (int r : itemRows) {
            writeSafe(sheet22, r, 18, ""); // 成年男子
            writeSafe(sheet22, r + 1, 18, ""); // 少年男子
            writeSafe(sheet22, r, 31, ""); // 成年女子
            writeSafe(sheet22, r + 1, 31, ""); // 少年女子
        }

        // 2. 決算額（全合計）の書き込み (Col J = 9)
        writeSafeNumeric(sheet22, 15, 9, totalTransport);
        writeSafeNumeric(sheet22, 17, 9, totalAccommodation);
        writeSafeNumeric(sheet22, 19, 9, totalTravelMisc);
        writeSafeNumeric(sheet22, 21, 9, totalParking);
        writeSafeNumeric(sheet22, 23, 9, totalRental);
        writeSafeNumeric(sheet22, 25, 9, totalCompensation);
        writeSafeNumeric(sheet22, 27, 9, totalSupplies);
        writeSafeNumeric(sheet22, 29, 9, totalService);

        // 3. 内訳（カテゴリ別合計）の書き込み
        for (int i = 0; i < 4; i++) {
            int col = (i == 0 || i == 1) ? 18 : 31;
            int offset = (i == 1 || i == 3) ? 1 : 0;

            // 決算額が0になる項目は空白にした方が綺麗なので、0より大きい場合のみ出力する
            if (catTransport[i] > 0) writeSafeNumeric(sheet22, 15 + offset, col, catTransport[i]);
            if (catAccommodation[i] > 0) writeSafeNumeric(sheet22, 17 + offset, col, catAccommodation[i]);
            if (catTravelMisc[i] > 0) writeSafeNumeric(sheet22, 19 + offset, col, catTravelMisc[i]);
            if (catParking[i] > 0) writeSafeNumeric(sheet22, 21 + offset, col, catParking[i]);
            if (catRental[i] > 0) writeSafeNumeric(sheet22, 23 + offset, col, catRental[i]);
            if (catCompensation[i] > 0) writeSafeNumeric(sheet22, 25 + offset, col, catCompensation[i]);
            if (catSupplies[i] > 0) writeSafeNumeric(sheet22, 27 + offset, col, catSupplies[i]);
            if (catService[i] > 0) writeSafeNumeric(sheet22, 29 + offset, col, catService[i]);
        }
    }

    // ===== シート名生成ヘルパー =====

    /** budgetTypeId → 補助金区分ラベル（ActivityController#budgetLabel と対応） */
    private String budgetTypeLabel(Integer budgetTypeId) {
        if (budgetTypeId == null) return "未設定";
        switch (budgetTypeId) {
            case 1: return "選手強化費";
            case 2: return "トップチーム活用事業";
            case 3: return "ふるさと選手活動支援";
            default: return "その他";
        }
    }

    /** targetCategory → ソート順（成年男子→1, 成年女子→2, 少年男子→3, 少年女子→4） */
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

    /** Excelシート名禁止文字（/\?*[]:）を _ に置換 */
    private String sanitizeSheetName(String name) {
        return name.replaceAll("[/\\\\?*\\[\\]:]", "_");
    }

    /** 1→①, 2→②, ..., 10→⑩, それ以上は (n) */
    private String circledNumber(int n) {
        String[] circles = {"①","②","③","④","⑤","⑥","⑦","⑧","⑨","⑩"};
        return (n >= 1 && n <= circles.length) ? circles[n - 1] : "(" + n + ")";
    }

    // ===== テンプレートシート名 =====
    private static final String SHEET_24 = "様式２－４①②事業実施・実績報告書（選手強化費）";
    private static final String SHEET_25 = "様式２－５①事業別参加者名簿（選手強化）";
    private static final String SHEET_26 = "様式２－６①事業別領収書１（選手強化）";
    private static final String SHEET_22 = "様式２－２－１　事業別決算書（選手強化費）";
    private static final String SHEET_21 = "様式２－１";
    private static final String SHEET_22_OVERVIEW = "様式２－２";
    private static final String SHEET_22_1_TOP = "様式２－２－１　事業別決算書（トップチーム活用)";
    private static final String SHEET_22_1_FURUSATO = "様式２－２－１　事業別決算書（ふるさと）";
    private static final String SHEET_23 = "様式２－３";

    public void exportAllFormsForProjects(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        buildCombinedWorkbook(projectIds, false, outputStream);
    }

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

            // 全プロジェクトをロードして仕様通りにソート
            // 順: 補助金区分ID昇順 → 種別順(成年男子→女子→少年男子→女子) → 活動日昇順 → ID昇順
            List<Project> allProjects = new ArrayList<>();
            for (int id : projectIds) {
                Project p = projectMapper.findById(id);
                if (p != null) allProjects.add(p);
            }
            allProjects.sort(Comparator
                .comparingInt((Project p) -> p.getBudgetTypeId() == null ? 99 : p.getBudgetTypeId())
                .thenComparingInt((Project p) -> categoryOrder(p.getTargetCategory()))
                .thenComparing((Project p) -> p.getEventDate() == null ? LocalDate.of(9999, 12, 31) : p.getEventDate())
                .thenComparingInt((Project p) -> p.getId() == null ? Integer.MAX_VALUE : p.getId()));

            if (includeSummary22) {
                List<Integer> sortedIds = new ArrayList<>();
                for (Project p : allProjects) sortedIds.add(p.getId());
                Sheet sheet22 = workbook.getSheet(SHEET_22);
                if (sheet22 != null) populate22Summary(sheet22, sortedIds);
            }

            // 様式2-4: (budgetTypeId + targetCategory) グループ内でペアリング
            // シート順: 2-4全て → 2-5全て → 2-6全てになるよう2-4を先に生成
            if (idx24 != -1) {
                Map<String, List<Project>> groups24 = new LinkedHashMap<>();
                for (Project p : allProjects) {
                    String key = (p.getBudgetTypeId() == null ? "0" : p.getBudgetTypeId())
                            + "_" + (p.getTargetCategory() == null ? "" : p.getTargetCategory());
                    groups24.computeIfAbsent(key, k -> new ArrayList<>()).add(p);
                }
                for (Map.Entry<String, List<Project>> entry : groups24.entrySet()) {
                    List<Project> gList = entry.getValue();
                    String btLabel = budgetTypeLabel(gList.get(0).getBudgetTypeId());
                    String cat = gList.get(0).getTargetCategory() == null ? "" : gList.get(0).getTargetCategory();
                    for (int i = 0, sheetNum = 1; i < gList.size(); i += 2, sheetNum++) {
                        Project left = gList.get(i);
                        Project right = (i + 1 < gList.size()) ? gList.get(i + 1) : null;
                        Sheet s = workbook.cloneSheet(idx24);
                        String nm = sanitizeSheetName("2-4_" + btLabel + "_" + cat + "_" + circledNumber(sheetNum));
                        workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, nm));
                        populate24Side(s, left.getId(), 0);
                        pruneTemplateEllipses24Side(s, 0, left);
                        if (right != null) {
                            populate24Side(s, right.getId(), 17);
                            pruneTemplateEllipses24Side(s, 17, right);
                        } else {
                            clearSide24(s, 17);
                            pruneTemplateEllipses24Side(s, 17, null);
                        }
                    }
                }
            }

            // 様式2-5: ソート済み順に1シートずつ、グループ内連番を付与
            if (idx25 != -1) {
                Map<String, Integer> counter25 = new LinkedHashMap<>();
                for (Project project : allProjects) {
                    String key = (project.getBudgetTypeId() == null ? "0" : project.getBudgetTypeId())
                            + "_" + (project.getTargetCategory() == null ? "" : project.getTargetCategory());
                    int num = counter25.merge(key, 1, Integer::sum);
                    String btLabel = budgetTypeLabel(project.getBudgetTypeId());
                    String cat = project.getTargetCategory() == null ? "" : project.getTargetCategory();
                    List<ProjectParticipant> participants = getLoadedParticipants(project.getId());
                    Sheet s = workbook.cloneSheet(idx25);
                    String nm = sanitizeSheetName("2-5_" + btLabel + "_" + cat + "_" + circledNumber(num));
                    workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, nm));
                    populate25(s, project, participants);
                }
            }

            // 様式2-6: 同様に1シートずつ
            if (idx26 != -1) {
                Map<String, Integer> counter26 = new LinkedHashMap<>();
                for (Project project : allProjects) {
                    String key = (project.getBudgetTypeId() == null ? "0" : project.getBudgetTypeId())
                            + "_" + (project.getTargetCategory() == null ? "" : project.getTargetCategory());
                    int num = counter26.merge(key, 1, Integer::sum);
                    String btLabel = budgetTypeLabel(project.getBudgetTypeId());
                    String cat = project.getTargetCategory() == null ? "" : project.getTargetCategory();
                    List<ProjectParticipant> participants = getLoadedParticipants(project.getId());
                    Sheet s = workbook.cloneSheet(idx26);
                    String nm = sanitizeSheetName("2-6_" + btLabel + "_" + cat + "_" + circledNumber(num));
                    workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, nm));
                    populate26(s, project, participants);
                }
            }

            // テンプレート原本を削除
            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                String name = workbook.getSheetName(i);
                boolean generated = name.startsWith("2-4_") || name.startsWith("2-5_") || name.startsWith("2-6_");
                boolean keepSummary = includeSummary22 && name.equals(SHEET_22);
                if (!generated && !keepSummary) {
                    workbook.removeSheetAt(i);
                }
            }

            if (workbook.getNumberOfSheets() == 0) {
                workbook.createSheet("データなし");
            }

            workbook.write(outputStream);
        }
    }

    // ===== Cycle 12A: 年度末決算ファイル一括出力 =====

    /**
     * 様式2-1・様式2-2（数式で自動計算）・2-2-1×3区分（選手強化費/トップチーム活用/ふるさと）・
     * 様式2-3（内示額・決算額）と、既存の2-4/2-5/2-6一括出力を1ブックにまとめて出力する。
     * 大容量プレビューはCycle 12C対象のため今回は含めない。
     */
    public void exportAnnualClosingBook(int year, List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportAnnualClosingBook(year, projectIds, null, outputStream);
    }

    /**
     * Cycle 12C: 提出情報（提出日・団体名・代表者）を画面から指定して出力する版。
     * submissionInfoがnullの場合は従来通り（実行時点の日付、団体名/代表者はテンプレート値のまま）。
     */
    public void exportAnnualClosingBook(int year, List<Integer> projectIds, AnnualSubmissionInfo submissionInfo, OutputStream outputStream) throws Exception {
        AnnualBuildResult result = buildAnnualClosingWorkbook(year, projectIds, submissionInfo);
        try (Workbook workbook = result.workbook) {
            workbook.write(outputStream);
        }
    }

    /**
     * Cycle 12C: 年度末出力のプレビュー用データを構築する。Excel出力（buildAnnualClosingWorkbook）と
     * 完全に同じビルド処理を通すため、プレビューと実際の出力で数値が食い違うことはない。
     */
    public AnnualPreviewData buildAnnualPreview(int year, List<Integer> projectIds, AnnualSubmissionInfo submissionInfo) throws Exception {
        AnnualBuildResult result = buildAnnualClosingWorkbook(year, projectIds, submissionInfo);
        result.workbook.close();
        return result.preview;
    }

    private static class AnnualBuildResult {
        final Workbook workbook;
        final AnnualPreviewData preview;
        AnnualBuildResult(Workbook workbook, AnnualPreviewData preview) {
            this.workbook = workbook;
            this.preview = preview;
        }
    }

    private AnnualBuildResult buildAnnualClosingWorkbook(int year, List<Integer> projectIds, AnnualSubmissionInfo submissionInfo) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        Workbook workbook;
        try (InputStream is = resource.getInputStream()) {
            workbook = WorkbookFactory.create(is);
        }

        AnnualPreviewData preview = new AnnualPreviewData();

        List<Project> allProjects = new ArrayList<>();
        for (int id : projectIds) {
            Project p = projectMapper.findById(id);
            if (p != null) allProjects.add(p);
        }
        sortProjectsForExport(allProjects);

        Sheet sheet21 = workbook.getSheet(SHEET_21);
        if (sheet21 != null) populateForm21(sheet21, year, submissionInfo, preview.getForm21());

        Map<String, CostTotals> byTypeCategory = populateAnnual221(workbook, allProjects, preview);

        Sheet sheet23 = workbook.getSheet(SHEET_23);
        if (sheet23 != null) populateForm23(sheet23, year, byTypeCategory, preview.getForm23());

        int idx24 = workbook.getSheetIndex(SHEET_24);
        int idx25 = workbook.getSheetIndex(SHEET_25);
        int idx26 = workbook.getSheetIndex(SHEET_26);
        generateActivityFormSheets(workbook, allProjects, idx24, idx25, idx26);

        for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
            String name = workbook.getSheetName(i);
            boolean generated = name.startsWith("2-4_") || name.startsWith("2-5_") || name.startsWith("2-6_");
            boolean keepBase = name.equals(SHEET_21) || name.equals(SHEET_22_OVERVIEW)
                    || name.equals(SHEET_22) || name.equals(SHEET_22_1_TOP) || name.equals(SHEET_22_1_FURUSATO)
                    || name.equals(SHEET_23);
            if (!generated && !keepBase) {
                workbook.removeSheetAt(i);
            }
        }

        workbook.setForceFormulaRecalculation(true);
        return new AnnualBuildResult(workbook, preview);
    }

    /** buildCombinedWorkbook等と同じソート順（補助金区分→種別→活動日→ID）を適用する */
    private void sortProjectsForExport(List<Project> projects) {
        projects.sort(Comparator
            .comparingInt((Project p) -> p.getBudgetTypeId() == null ? 99 : p.getBudgetTypeId())
            .thenComparingInt((Project p) -> categoryOrder(p.getTargetCategory()))
            .thenComparing((Project p) -> p.getEventDate() == null ? LocalDate.of(9999, 12, 31) : p.getEventDate())
            .thenComparingInt((Project p) -> p.getId() == null ? Integer.MAX_VALUE : p.getId()));
    }

    /**
     * 様式2-1に提出日・対象年度・団体名/代表者・担当者(AA42)/TEL(AA43)を書き込む。
     * submissionInfoが指定されていれば画面入力値を使い、なければ従来通り実行時点の日付とテンプレート値を使う
     * （12Aの `/activity/export/annual` はsubmissionInfo=nullで呼ばれるため、挙動は変えない）。
     * FAX/E-mail(AA44-45)は、DBに対応するデータ源が存在しないため引き続きテンプレートの既存値のまま。
     */
    private void populateForm21(Sheet sheet, int year, AnnualSubmissionInfo submissionInfo, Form21Preview previewOut) {
        int submitYear, submitMonth, submitDay;
        if (submissionInfo != null && submissionInfo.getSubmitYear() != null
                && submissionInfo.getSubmitMonth() != null && submissionInfo.getSubmitDay() != null) {
            submitYear = submissionInfo.getSubmitYear();
            submitMonth = submissionInfo.getSubmitMonth();
            submitDay = submissionInfo.getSubmitDay();
        } else {
            LocalDate today = LocalDate.now();
            submitYear = getReiwaYear(today.getYear());
            submitMonth = today.getMonthValue();
            submitDay = today.getDayOfMonth();
        }
        writeSafeNumeric(sheet, 2, 28, submitYear);  // AC3: 提出日(年)
        writeSafeNumeric(sheet, 2, 32, submitMonth); // AG3: 提出日(月)
        writeSafeNumeric(sheet, 2, 36, submitDay);   // AK3: 提出日(日)
        writeSafeNumeric(sheet, 14, 4, getReiwaYear(year)); // E15: 対象年度（選択年度を必ず反映）

        if (submissionInfo != null && submissionInfo.getOrganizationNamePart1() != null) {
            writeSafe(sheet, 8, 27, submissionInfo.getOrganizationNamePart1());  // AB9
        }
        if (submissionInfo != null && submissionInfo.getOrganizationNamePart2() != null) {
            writeSafe(sheet, 8, 34, submissionInfo.getOrganizationNamePart2());  // AI9
        }
        if (submissionInfo != null && submissionInfo.getRepresentativeTitleAndName() != null) {
            writeSafe(sheet, 10, 27, submissionInfo.getRepresentativeTitleAndName()); // AB11
        }

        previewOut.setSubmitYear(submitYear);
        previewOut.setSubmitMonth(submitMonth);
        previewOut.setSubmitDay(submitDay);
        previewOut.setFiscalYearReiwa(getReiwaYear(year));
        previewOut.setOrganizationNamePart1(getCellString(sheet, 8, 27));
        previewOut.setOrganizationNamePart2(getCellString(sheet, 8, 34));
        previewOut.setRepresentativeTitleAndName(getCellString(sheet, 10, 27));

        try {
            User activeUser = userSettingService.getActiveUser();
            if (activeUser != null) {
                writeSafe(sheet, 41, 26, activeUser.getName());                  // AA42: 担当者
                writeSafe(sheet, 42, 26, activeUser.getFormattedPhoneNumber());  // AA43: TEL
            }
        } catch (Exception e) {
            // ユーザー取得失敗時はテンプレート値のまま
        }
        previewOut.setContactName(getCellString(sheet, 41, 26));
        previewOut.setContactTel(getCellString(sheet, 42, 26));
        previewOut.setContactFax(getCellString(sheet, 43, 26));
        previewOut.setContactEmail(getCellString(sheet, 44, 26));
    }

    /** 区分別（選手強化費/トップチーム/ふるさと）の費目集計値 */
    private static class CostTotals {
        long transport, accommodation, travelMisc, parking, rental, compensation, supplies, service;

        long total() {
            return transport + accommodation + travelMisc + parking + rental + compensation + supplies + service;
        }
    }

    // ===== Cycle 12C: プレビュー用データ構造（Excel出力と同じ集計結果を参照する） =====

    /** 年度末出力の提出情報（画面から入力）。nullの場合は従来通り実行時点の日付・テンプレート値を使う。 */
    public static class AnnualSubmissionInfo {
        private Integer submitYear;  // 令和年（数値）
        private Integer submitMonth;
        private Integer submitDay;
        private String organizationNamePart1;
        private String organizationNamePart2;
        private String representativeTitleAndName;

        public Integer getSubmitYear() { return submitYear; }
        public void setSubmitYear(Integer submitYear) { this.submitYear = submitYear; }
        public Integer getSubmitMonth() { return submitMonth; }
        public void setSubmitMonth(Integer submitMonth) { this.submitMonth = submitMonth; }
        public Integer getSubmitDay() { return submitDay; }
        public void setSubmitDay(Integer submitDay) { this.submitDay = submitDay; }
        public String getOrganizationNamePart1() { return organizationNamePart1; }
        public void setOrganizationNamePart1(String v) { this.organizationNamePart1 = v; }
        public String getOrganizationNamePart2() { return organizationNamePart2; }
        public void setOrganizationNamePart2(String v) { this.organizationNamePart2 = v; }
        public String getRepresentativeTitleAndName() { return representativeTitleAndName; }
        public void setRepresentativeTitleAndName(String v) { this.representativeTitleAndName = v; }
    }

    /** 費目内訳の表示用ビュー。該当区分で対象外の費目はnullにする（画面側で「対象外」表示に使う）。 */
    public static class CostBreakdownView {
        private Long transport, accommodation, travelMisc, parking, rental, compensation, supplies, service;
        private long total;

        public Long getTransport() { return transport; }
        public void setTransport(Long v) { this.transport = v; }
        public Long getAccommodation() { return accommodation; }
        public void setAccommodation(Long v) { this.accommodation = v; }
        public Long getTravelMisc() { return travelMisc; }
        public void setTravelMisc(Long v) { this.travelMisc = v; }
        public Long getParking() { return parking; }
        public void setParking(Long v) { this.parking = v; }
        public Long getRental() { return rental; }
        public void setRental(Long v) { this.rental = v; }
        public Long getCompensation() { return compensation; }
        public void setCompensation(Long v) { this.compensation = v; }
        public Long getSupplies() { return supplies; }
        public void setSupplies(Long v) { this.supplies = v; }
        public Long getService() { return service; }
        public void setService(Long v) { this.service = v; }
        public long getTotal() { return total; }
        public void setTotal(long total) { this.total = total; }
    }

    public static class Form21Preview {
        private int submitYear, submitMonth, submitDay, fiscalYearReiwa;
        private String organizationNamePart1, organizationNamePart2, representativeTitleAndName;
        private String contactName, contactTel, contactFax, contactEmail;

        public int getSubmitYear() { return submitYear; }
        public void setSubmitYear(int v) { this.submitYear = v; }
        public int getSubmitMonth() { return submitMonth; }
        public void setSubmitMonth(int v) { this.submitMonth = v; }
        public int getSubmitDay() { return submitDay; }
        public void setSubmitDay(int v) { this.submitDay = v; }
        public int getFiscalYearReiwa() { return fiscalYearReiwa; }
        public void setFiscalYearReiwa(int v) { this.fiscalYearReiwa = v; }
        public String getOrganizationNamePart1() { return organizationNamePart1; }
        public void setOrganizationNamePart1(String v) { this.organizationNamePart1 = v; }
        public String getOrganizationNamePart2() { return organizationNamePart2; }
        public void setOrganizationNamePart2(String v) { this.organizationNamePart2 = v; }
        public String getRepresentativeTitleAndName() { return representativeTitleAndName; }
        public void setRepresentativeTitleAndName(String v) { this.representativeTitleAndName = v; }
        public String getContactName() { return contactName; }
        public void setContactName(String v) { this.contactName = v; }
        public String getContactTel() { return contactTel; }
        public void setContactTel(String v) { this.contactTel = v; }
        public String getContactFax() { return contactFax; }
        public void setContactFax(String v) { this.contactFax = v; }
        public String getContactEmail() { return contactEmail; }
        public void setContactEmail(String v) { this.contactEmail = v; }
    }

    public static class Form22Preview {
        private Map<String, CostBreakdownView> byBudgetType = new LinkedHashMap<>();
        private long grandTotal;
        private boolean matchesForm221Total;

        public Map<String, CostBreakdownView> getByBudgetType() { return byBudgetType; }
        public long getGrandTotal() { return grandTotal; }
        public void setGrandTotal(long v) { this.grandTotal = v; }
        public boolean isMatchesForm221Total() { return matchesForm221Total; }
        public void setMatchesForm221Total(boolean v) { this.matchesForm221Total = v; }
    }

    public static class Form23Row {
        private String budgetTypeLabel;
        private String targetCategory;
        private long allocated;
        private long decided;
        private long difference;

        public String getBudgetTypeLabel() { return budgetTypeLabel; }
        public void setBudgetTypeLabel(String v) { this.budgetTypeLabel = v; }
        public String getTargetCategory() { return targetCategory; }
        public void setTargetCategory(String v) { this.targetCategory = v; }
        public long getAllocated() { return allocated; }
        public void setAllocated(long v) { this.allocated = v; }
        public long getDecided() { return decided; }
        public void setDecided(long v) { this.decided = v; }
        public long getDifference() { return difference; }
        public void setDifference(long v) { this.difference = v; }
    }

    public static class Form23Preview {
        private List<Form23Row> rows = new ArrayList<>();
        private String topChumNote;

        public List<Form23Row> getRows() { return rows; }
        public String getTopChumNote() { return topChumNote; }
        public void setTopChumNote(String v) { this.topChumNote = v; }
    }

    /** 年度末プレビュー全体。Excel出力と同じ集計ヘルパーの結果をそのまま格納する（プレビュー専用の再計算はしない）。 */
    public static class AnnualPreviewData {
        private Form21Preview form21 = new Form21Preview();
        private Form22Preview form22 = new Form22Preview();
        private Map<String, CostBreakdownView> form221 = new LinkedHashMap<>(); // key: training/top/furusato
        private Form23Preview form23 = new Form23Preview();
        private List<String> warnings = new ArrayList<>();

        public Form21Preview getForm21() { return form21; }
        public Form22Preview getForm22() { return form22; }
        public Map<String, CostBreakdownView> getForm221() { return form221; }
        public Form23Preview getForm23() { return form23; }
        public List<String> getWarnings() { return warnings; }
    }

    /**
     * budgetTypeId(1=選手強化費/2=トップチーム/3=ふるさと)ごとに費目を集計し、
     * 各2-2-1シートへ書き込む。各区分が対応していない費目（例:トップチームの旅行雑費・駐車料、
     * ふるさとの借用料・駐車料・報償費）にデータがある場合は、黙って捨てず例外で処理を止める。
     *
     * 戻り値は "budgetTypeId_targetCategory" をキーとした種別別集計。2-2-1の内訳欄と様式2-3の
     * 両方が同じ集計結果を参照できるよう、ここで一度だけ計算する（Cycle 12B: 集計の二重化を避ける）。
     */
    private Map<String, CostTotals> populateAnnual221(Workbook workbook, List<Project> allProjects, AnnualPreviewData preview) {
        Map<Integer, CostTotals> totalsByType = new LinkedHashMap<>();
        // budgetTypeId_targetCategory 単位の集計。2-2-1内訳欄（選手強化費のみ）と様式2-3（選手強化費・ふるさと）で共用する。
        Map<String, CostTotals> byTypeCategory = new LinkedHashMap<>();

        for (Project p : allProjects) {
            Integer bt = p.getBudgetTypeId();
            if (bt == null || bt < 1 || bt > 3) continue;

            ProjectSummaryExpense summary = summaryMapper.findByProjectId(p.getId());
            List<ProjectParticipant> participants = getLoadedParticipants(p.getId());

            long transport = 0, accommodation = 0;
            for (ProjectParticipant part : participants) {
                if (part.getExpense() != null) {
                    transport += nz(part.getExpense().getTransportCost());
                    accommodation += nz(part.getExpense().getAccommodationCost());
                }
            }
            long travelMisc = 0, parking = 0, rental = 0, compensation = 0, supplies = 0, service = 0;
            if (summary != null) {
                travelMisc = (long) nz(summary.getTravelMiscCost()) * participants.size() * nz(summary.getTravelMiscDays());
                parking = nz(summary.getParkingCost());
                rental = nz(summary.getRentalCost());
                compensation = nz(summary.getCompensationCost());
                supplies = nz(summary.getSuppliesCost());
                service = nz(summary.getServiceCost());
            }

            if (bt == 2 && (travelMisc > 0 || parking > 0)) {
                throw new IllegalStateException("トップチーム活用事業「" + p.getName()
                        + "」に旅行雑費または駐車料金の入力がありますが、様式２－２－１　事業別決算書（トップチーム活用)には"
                        + "これらを書き込む欄がありません。年度末出力を中止しました。データを確認してください。");
            }
            if (bt == 3 && (rental > 0 || parking > 0 || compensation > 0)) {
                throw new IllegalStateException("ふるさと選手活動支援「" + p.getName()
                        + "」に借用料・駐車料金・報償費のいずれかの入力がありますが、様式２－２－１　事業別決算書（ふるさと）には"
                        + "これらを書き込む欄がありません。年度末出力を中止しました。データを確認してください。");
            }

            CostTotals totals = totalsByType.computeIfAbsent(bt, k -> new CostTotals());
            totals.transport += transport;
            totals.accommodation += accommodation;
            totals.travelMisc += travelMisc;
            totals.parking += parking;
            totals.rental += rental;
            totals.compensation += compensation;
            totals.supplies += supplies;
            totals.service += service;

            if (isKnownCategory(p.getTargetCategory())) {
                String key = bt + "_" + p.getTargetCategory();
                CostTotals catTotals = byTypeCategory.computeIfAbsent(key, k -> new CostTotals());
                catTotals.transport += transport;
                catTotals.accommodation += accommodation;
                catTotals.travelMisc += travelMisc;
                catTotals.parking += parking;
                catTotals.rental += rental;
                catTotals.compensation += compensation;
                catTotals.supplies += supplies;
                catTotals.service += service;
            }
            // 種別が未設定/不明な事業は、J列の総額には含まれるが内訳欄・様式2-3には反映できない
            // （内訳欄・様式2-3の対象行は種別4区分の固定枠のため）。既知の制約。
        }

        Map<String, CostTotals> trainingByCategory = new LinkedHashMap<>();
        for (Map.Entry<String, CostTotals> e : byTypeCategory.entrySet()) {
            if (e.getKey().startsWith("1_")) {
                trainingByCategory.put(e.getKey().substring(2), e.getValue());
            }
        }

        writeTraining221(workbook.getSheet(SHEET_22), totalsByType.getOrDefault(1, new CostTotals()));
        writeTraining221Breakdown(workbook.getSheet(SHEET_22), trainingByCategory);
        writeTop221(workbook.getSheet(SHEET_22_1_TOP), totalsByType.getOrDefault(2, new CostTotals()));
        writeFurusato221(workbook.getSheet(SHEET_22_1_FURUSATO), totalsByType.getOrDefault(3, new CostTotals()));

        // ===== プレビュー用データ（Excel書込と同じtotalsByTypeから作る。二重集計はしない） =====
        CostTotals trainingTotals = totalsByType.getOrDefault(1, new CostTotals());
        CostTotals topTotals = totalsByType.getOrDefault(2, new CostTotals());
        CostTotals furusatoTotals = totalsByType.getOrDefault(3, new CostTotals());

        CostBreakdownView trainingView = toBreakdownView(trainingTotals, true, true, true, true);
        CostBreakdownView topView = toBreakdownView(topTotals, false, false, true, true);
        CostBreakdownView furusatoView = toBreakdownView(furusatoTotals, true, false, false, false);

        preview.getForm221().put("training", trainingView);
        preview.getForm221().put("top", topView);
        preview.getForm221().put("furusato", furusatoView);

        preview.getForm22().getByBudgetType().put(budgetTypeLabel(1), trainingView);
        preview.getForm22().getByBudgetType().put(budgetTypeLabel(2), topView);
        preview.getForm22().getByBudgetType().put(budgetTypeLabel(3), furusatoView);
        long grandTotal = trainingTotals.total() + topTotals.total() + furusatoTotals.total();
        preview.getForm22().setGrandTotal(grandTotal);
        long form221Sum = trainingView.getTotal() + topView.getTotal() + furusatoView.getTotal();
        boolean matches = grandTotal == form221Sum;
        preview.getForm22().setMatchesForm221Total(matches);
        if (!matches) {
            preview.getWarnings().add("様式2-2の合計と2-2-1の合計が一致しません。データを確認してください。");
        }

        return byTypeCategory;
    }

    /** CostTotalsを画面表示用に変換する。対象外の費目はnullにする（画面側で「対象外」表示に使う）。 */
    private CostBreakdownView toBreakdownView(CostTotals t, boolean travelMiscApplicable, boolean parkingApplicable,
            boolean rentalApplicable, boolean compensationApplicable) {
        CostBreakdownView v = new CostBreakdownView();
        v.setTransport(t.transport);
        v.setAccommodation(t.accommodation);
        v.setTravelMisc(travelMiscApplicable ? t.travelMisc : null);
        v.setParking(parkingApplicable ? t.parking : null);
        v.setRental(rentalApplicable ? t.rental : null);
        v.setCompensation(compensationApplicable ? t.compensation : null);
        v.setSupplies(t.supplies);
        v.setService(t.service);
        v.setTotal(t.total());
        return v;
    }

    private boolean isKnownCategory(String category) {
        return "成年男子".equals(category) || "少年男子".equals(category)
                || "成年女子".equals(category) || "少年女子".equals(category);
    }

    /** 選手強化費 2-2-1: J16交通費/J18宿泊費/J20旅行雑費/J22駐車料金/J24借用料/J26報償費/J28需用費/J30役務費/J32対象外経費 */
    private void writeTraining221(Sheet sheet, CostTotals t) {
        if (sheet == null) return;
        writeSafeNumeric(sheet, 15, 9, t.transport);
        writeSafeNumeric(sheet, 17, 9, t.accommodation);
        writeSafeNumeric(sheet, 19, 9, t.travelMisc);
        writeSafeNumeric(sheet, 21, 9, t.parking);
        writeSafeNumeric(sheet, 23, 9, t.rental);
        writeSafeNumeric(sheet, 25, 9, t.compensation);
        writeSafeNumeric(sheet, 27, 9, t.supplies);
        writeSafeNumeric(sheet, 29, 9, t.service);
        writeSafeNumeric(sheet, 31, 9, 0L); // 対象外経費: DB項目なしのため常に0
    }

    /**
     * 選手強化費2-2-1の内訳欄（O列:成年男子/少年男子ラベル→S列に値、AB列:成年女子/少年女子ラベル→AL列に値）へ、
     * 種別別の集計値を書き込む。原本の実データ（例:S16=830550）を必ず上書きし、過去データが残らないようにする。
     */
    private void writeTraining221Breakdown(Sheet sheet, Map<String, CostTotals> byCategory) {
        if (sheet == null) return;
        CostTotals male20 = byCategory.getOrDefault("成年男子", new CostTotals());
        CostTotals male10 = byCategory.getOrDefault("少年男子", new CostTotals());
        CostTotals female20 = byCategory.getOrDefault("成年女子", new CostTotals());
        CostTotals female10 = byCategory.getOrDefault("少年女子", new CostTotals());

        writeBreakdownPair(sheet, 15, male20.transport, male10.transport, female20.transport, female10.transport);           // 16/17 交通費
        writeBreakdownPair(sheet, 17, male20.accommodation, male10.accommodation, female20.accommodation, female10.accommodation); // 18/19 宿泊費
        writeBreakdownPair(sheet, 19, male20.travelMisc, male10.travelMisc, female20.travelMisc, female10.travelMisc);        // 20/21 旅行雑費
        writeBreakdownPair(sheet, 21, male20.parking, male10.parking, female20.parking, female10.parking);                   // 22/23 駐車料金
        writeBreakdownPair(sheet, 23, male20.rental, male10.rental, female20.rental, female10.rental);                       // 24/25 借用料
        writeBreakdownPair(sheet, 25, male20.compensation, male10.compensation, female20.compensation, female10.compensation); // 26/27 報償費
        writeBreakdownPair(sheet, 27, male20.supplies, male10.supplies, female20.supplies, female10.supplies);               // 28/29 需用費
        writeBreakdownPair(sheet, 29, male20.service, male10.service, female20.service, female10.service);                   // 30/31 役務費
        writeBreakdownPair(sheet, 31, 0L, 0L, 0L, 0L);                                                                        // 32/33 対象外経費（DB項目なし）
    }

    private void writeBreakdownPair(Sheet sheet, int topRow0idx, long adultMale, long youthMale, long adultFemale, long youthFemale) {
        writeSafeNumeric(sheet, topRow0idx, 18, adultMale);        // S列（成年男子、S:X結合の金額欄）
        writeSafeNumeric(sheet, topRow0idx + 1, 18, youthMale);    // S列 次行（少年男子、S:X結合の金額欄）
        writeSafeNumeric(sheet, topRow0idx, 31, adultFemale);      // AF列（成年女子、AF:AK結合の金額欄。AL列は単位「円」のため書き込み禁止）
        writeSafeNumeric(sheet, topRow0idx + 1, 31, youthFemale);  // AF列 次行（少年女子、AF:AK結合の金額欄）
    }

    /** トップチーム活用 2-2-1: J16交通費/J18宿泊費/J22使用料賃借料/J24報償費/J28需用費/J30役務費/J32対象外経費 */
    private void writeTop221(Sheet sheet, CostTotals t) {
        if (sheet == null) return;
        writeSafeNumeric(sheet, 15, 9, t.transport);
        writeSafeNumeric(sheet, 17, 9, t.accommodation);
        writeSafeNumeric(sheet, 21, 9, t.rental);
        writeSafeNumeric(sheet, 23, 9, t.compensation);
        writeSafeNumeric(sheet, 27, 9, t.supplies);
        writeSafeNumeric(sheet, 29, 9, t.service);
        writeSafeNumeric(sheet, 31, 9, 0L);
    }

    /** ふるさと 2-2-1: J16交通費/J18宿泊費/J20旅行雑費/J28需用費/J30役務費/J32対象外経費 */
    private void writeFurusato221(Sheet sheet, CostTotals t) {
        if (sheet == null) return;
        writeSafeNumeric(sheet, 15, 9, t.transport);
        writeSafeNumeric(sheet, 17, 9, t.accommodation);
        writeSafeNumeric(sheet, 19, 9, t.travelMisc);
        writeSafeNumeric(sheet, 27, 9, t.supplies);
        writeSafeNumeric(sheet, 29, 9, t.service);
        writeSafeNumeric(sheet, 31, 9, 0L);

        // 内訳欄(O16/O18/O20)は原本では日付別領収書の内訳テキスト（例:「【5/24】14,110円…」）であり、
        // DBの集計データからは再現できない。推測で書かず、必ずクリアして過去データを残さない。
        clearCell(sheet, 15, 14); // O16
        clearCell(sheet, 17, 14); // O18
        clearCell(sheet, 19, 14); // O20
    }

    // ===== Cycle 12B: 様式2-3（変更実績報告書・下部表のみ） =====

    /** 様式2-3のB列種別ラベルが記載される行範囲（1-indexed、原本「補助額変更後」表基準） */
    private static final int FORM23_TRAINING_ROW_START = 25;
    private static final int FORM23_TRAINING_ROW_END = 28;
    private static final int FORM23_FURUSATO_ROW_START = 33;
    private static final int FORM23_FURUSATO_ROW_END = 33;
    // トップチーム(29〜31行)は原本が「例）」行のみのため、非例示行が見つからない限り書き込まない。

    /**
     * 様式2-3の下部「補助額変更後」表に、内示額(K列)と決算額(T列)・総額(AC列)を書き込む。
     * 上部の「変更理由・移動額」欄はKazumax合意により自動計算しない（触らない）。
     * トップチームは原本に非例示行がないため、今回は書き込み対象外。
     */
    private void populateForm23(Sheet sheet, int fiscalYear, Map<String, CostTotals> byTypeCategory, Form23Preview previewOut) {
        List<BudgetAllocation> allocations = budgetAllocationMapper.findByFiscalYear(fiscalYear);
        Map<String, Long> allocatedByKey = new LinkedHashMap<>();
        for (BudgetAllocation a : allocations) {
            long amount = a.getAllocatedAmount() == null ? 0L : a.getAllocatedAmount();
            allocatedByKey.put(a.getBudgetTypeId() + "_" + a.getTargetCategory(), amount);
        }

        long trainingSectionTotal = writeForm23Section(sheet, 1, FORM23_TRAINING_ROW_START, FORM23_TRAINING_ROW_END,
                byTypeCategory, allocatedByKey, previewOut);
        // 総額（合計）はAC25:AK28が1セルに結合されているため、セクション先頭行にのみ書き込む
        writeSafeNumeric(sheet, FORM23_TRAINING_ROW_START - 1, 28, trainingSectionTotal); // AC25

        long furusatoSectionTotal = writeForm23Section(sheet, 3, FORM23_FURUSATO_ROW_START, FORM23_FURUSATO_ROW_END,
                byTypeCategory, allocatedByKey, previewOut);
        writeSafeNumeric(sheet, FORM23_FURUSATO_ROW_START - 1, 28, furusatoSectionTotal); // AC33（単一行のためT列と同額）

        // トップチームの内示額・決算額があっても、原本に非例示行がないため様式2-3へは書き込まない。
        boolean hasTopData = false;
        for (String k : byTypeCategory.keySet()) if (k.startsWith("2_")) hasTopData = true;
        for (String k : allocatedByKey.keySet()) if (k.startsWith("2_")) hasTopData = true;
        if (hasTopData) {
            previewOut.setTopChumNote("トップチーム活用事業に内示額または決算額のデータがありますが、"
                    + "様式2-3の原本には正式な入力行（非例示行）が存在しないため、自動書込していません。");
        }
    }

    /**
     * 指定した補助金区分・行範囲内で、B列を動的検索してK列(内示額)・T列(決算額)を書き込む。
     * 該当カテゴリの実績または内示額があるのに一致する行が見つからない場合は、黙って捨てず例外で停止する。
     * 戻り値はセクション内の決算額合計（AC列の結合セルに使う）。
     */
    private long writeForm23Section(Sheet sheet, int budgetTypeId, int rowStart, int rowEnd,
            Map<String, CostTotals> byTypeCategory, Map<String, Long> allocatedByKey, Form23Preview previewOut) {
        java.util.LinkedHashSet<String> categories = new java.util.LinkedHashSet<>();
        String prefix = budgetTypeId + "_";
        for (String k : byTypeCategory.keySet()) if (k.startsWith(prefix)) categories.add(k.substring(prefix.length()));
        for (String k : allocatedByKey.keySet()) if (k.startsWith(prefix)) categories.add(k.substring(prefix.length()));

        long sectionTotal = 0;
        for (String category : categories) {
            long allocated = allocatedByKey.getOrDefault(prefix + category, 0L);
            CostTotals t = byTypeCategory.getOrDefault(prefix + category, new CostTotals());
            long decided = t.total();
            sectionTotal += decided;

            Form23Row row = new Form23Row();
            row.setBudgetTypeLabel(budgetTypeLabel(budgetTypeId));
            row.setTargetCategory(category);
            row.setAllocated(allocated);
            row.setDecided(decided);
            row.setDifference(decided - allocated);
            previewOut.getRows().add(row);

            if (allocated == 0 && decided == 0) continue; // 内示額も決算額も0円なら行探索・書込は不要

            int row1idx = findCategoryRow(sheet, rowStart, rowEnd, category);
            if (row1idx == -1) {
                throw new IllegalStateException(budgetTypeLabel(budgetTypeId) + "「" + category
                        + "」に内示額または決算額のデータがありますが、様式２－３（" + rowStart + "〜" + rowEnd + "行）に該当する種別の行が見つかりません。"
                        + "年度末出力を中止しました。原本テンプレートまたは種別名を確認してください。");
            }
            writeSafeNumeric(sheet, row1idx - 1, 10, allocated); // K列: 内示額
            writeSafeNumeric(sheet, row1idx - 1, 19, decided);   // T列: 移動後の総額（決算額）
        }
        return sectionTotal;
    }

    /**
     * B列文字列を正規化して比較し、指定行範囲内でカテゴリ名と一致する行を探す。
     * 「例）」「例)」で始まる行（原本のサンプル行）は対象外とする。
     * 完全一致を最優先し、完全一致が無い場合のみ部分一致（前方/後方にふりがな等が付与された表記ゆれ想定）に
     * フォールバックする。完全一致が取れるならそちらを使うことで、部分一致による誤った行の混同を避ける。
     * 見つからない場合は -1 を返す。
     */
    private int findCategoryRow(Sheet sheet, int rowStart, int rowEnd, String category) {
        String target = normalizeForMatch(category);
        Integer containsMatchRow = null;
        for (int r = rowStart; r <= rowEnd; r++) {
            Row row = sheet.getRow(r - 1);
            if (row == null) continue;
            org.apache.poi.ss.usermodel.Cell bCell = row.getCell(1); // B列
            if (bCell == null || bCell.getCellType() != org.apache.poi.ss.usermodel.CellType.STRING) continue;
            String raw = bCell.getStringCellValue();
            if (raw == null) continue;
            String normalized = normalizeForMatch(raw);
            if (normalized.startsWith("例）") || normalized.startsWith("例)")) continue;
            if (normalized.equals(target)) return r; // 完全一致は即確定
            if (containsMatchRow == null && normalized.contains(target)) {
                containsMatchRow = r; // 完全一致が見つからなかった場合のフォールバック候補
            }
        }
        return containsMatchRow != null ? containsMatchRow : -1;
    }

    /** 空白（半角・全角）を除去して比較する簡易正規化 */
    private String normalizeForMatch(String s) {
        if (s == null) return "";
        return s.replaceAll("[\\s　]", "");
    }

    /**
     * 既存2-4/2-5/2-6の生成ロジック（buildCombinedWorkbookと同じ内容）。
     * 既存メソッドへの影響を避けるため独立メソッドとして切り出している（意図的な重複、P3報告書に記載）。
     */
    private void generateActivityFormSheets(Workbook workbook, List<Project> allProjects, int idx24, int idx25, int idx26) {
        if (idx24 != -1) {
            Map<String, List<Project>> groups24 = new LinkedHashMap<>();
            for (Project p : allProjects) {
                String key = (p.getBudgetTypeId() == null ? "0" : p.getBudgetTypeId())
                        + "_" + (p.getTargetCategory() == null ? "" : p.getTargetCategory());
                groups24.computeIfAbsent(key, k -> new ArrayList<>()).add(p);
            }
            for (Map.Entry<String, List<Project>> entry : groups24.entrySet()) {
                List<Project> gList = entry.getValue();
                String btLabel = budgetTypeLabel(gList.get(0).getBudgetTypeId());
                String cat = gList.get(0).getTargetCategory() == null ? "" : gList.get(0).getTargetCategory();
                for (int i = 0, sheetNum = 1; i < gList.size(); i += 2, sheetNum++) {
                    Project left = gList.get(i);
                    Project right = (i + 1 < gList.size()) ? gList.get(i + 1) : null;
                    Sheet s = workbook.cloneSheet(idx24);
                    String nm = sanitizeSheetName("2-4_" + btLabel + "_" + cat + "_" + circledNumber(sheetNum));
                    workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, nm));
                    populate24Side(s, left.getId(), 0);
                    pruneTemplateEllipses24Side(s, 0, left);
                    if (right != null) {
                        populate24Side(s, right.getId(), 17);
                        pruneTemplateEllipses24Side(s, 17, right);
                    } else {
                        clearSide24(s, 17);
                        pruneTemplateEllipses24Side(s, 17, null);
                    }
                }
            }
        }

        if (idx25 != -1) {
            Map<String, Integer> counter25 = new LinkedHashMap<>();
            for (Project project : allProjects) {
                String key = (project.getBudgetTypeId() == null ? "0" : project.getBudgetTypeId())
                        + "_" + (project.getTargetCategory() == null ? "" : project.getTargetCategory());
                int num = counter25.merge(key, 1, Integer::sum);
                String btLabel = budgetTypeLabel(project.getBudgetTypeId());
                String cat = project.getTargetCategory() == null ? "" : project.getTargetCategory();
                List<ProjectParticipant> participants = getLoadedParticipants(project.getId());
                Sheet s = workbook.cloneSheet(idx25);
                String nm = sanitizeSheetName("2-5_" + btLabel + "_" + cat + "_" + circledNumber(num));
                workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, nm));
                populate25(s, project, participants);
            }
        }

        if (idx26 != -1) {
            Map<String, Integer> counter26 = new LinkedHashMap<>();
            for (Project project : allProjects) {
                String key = (project.getBudgetTypeId() == null ? "0" : project.getBudgetTypeId())
                        + "_" + (project.getTargetCategory() == null ? "" : project.getTargetCategory());
                int num = counter26.merge(key, 1, Integer::sum);
                String btLabel = budgetTypeLabel(project.getBudgetTypeId());
                String cat = project.getTargetCategory() == null ? "" : project.getTargetCategory();
                List<ProjectParticipant> participants = getLoadedParticipants(project.getId());
                Sheet s = workbook.cloneSheet(idx26);
                String nm = sanitizeSheetName("2-6_" + btLabel + "_" + cat + "_" + circledNumber(num));
                workbook.setSheetName(workbook.getSheetIndex(s), uniqueName(workbook, nm));
                populate26(s, project, participants);
            }
        }
    }

    private String uniqueName(Workbook wb, String base) {
        if (base.length() > 31) base = base.substring(0, 31);
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

    private void exportMultiSheet(String prefix, String templateName, List<Integer> projectIds, OutputStream outputStream, SheetPopulator populator) throws Exception {
        ClassPathResource resource = new ClassPathResource("書類.xlsx");
        try (InputStream is = resource.getInputStream();
             Workbook workbook = WorkbookFactory.create(is)) {

            int templateIndex = workbook.getSheetIndex(templateName);
            if (templateIndex == -1) throw new IllegalArgumentException("Template sheet not found: " + templateName);

            // buildCombinedWorkbook と同じソート・グループ化ルールを適用
            List<Project> sorted = new ArrayList<>();
            for (int id : projectIds) {
                Project p = projectMapper.findById(id);
                if (p != null) sorted.add(p);
            }
            sorted.sort(Comparator
                .comparingInt((Project p) -> p.getBudgetTypeId() == null ? 99 : p.getBudgetTypeId())
                .thenComparingInt((Project p) -> categoryOrder(p.getTargetCategory()))
                .thenComparing((Project p) -> p.getEventDate() == null ? LocalDate.of(9999, 12, 31) : p.getEventDate())
                .thenComparingInt((Project p) -> p.getId() == null ? Integer.MAX_VALUE : p.getId()));

            Map<String, Integer> counter = new LinkedHashMap<>();
            for (Project project : sorted) {
                String key = (project.getBudgetTypeId() == null ? "0" : project.getBudgetTypeId())
                        + "_" + (project.getTargetCategory() == null ? "" : project.getTargetCategory());
                int num = counter.merge(key, 1, Integer::sum);
                String btLabel = budgetTypeLabel(project.getBudgetTypeId());
                String cat = project.getTargetCategory() == null ? "" : project.getTargetCategory();
                ProjectSummaryExpense summary = summaryMapper.findByProjectId(project.getId());
                List<ProjectParticipant> participants = getLoadedParticipants(project.getId());

                Sheet newSheet = workbook.cloneSheet(templateIndex);
                String nm = sanitizeSheetName(prefix + "_" + btLabel + "_" + cat + "_" + circledNumber(num));
                workbook.setSheetName(workbook.getSheetIndex(newSheet), uniqueName(workbook, nm));

                populator.populate(newSheet, project, summary, participants);
            }

            for (int i = workbook.getNumberOfSheets() - 1; i >= 0; i--) {
                if (!workbook.getSheetName(i).startsWith(prefix + "_")) {
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

    private void writeSafeNumeric(Sheet sheet, int rowIndex, int colIndex, long value) {
        Row row = sheet.getRow(rowIndex);
        if (row == null) row = sheet.createRow(rowIndex);
        org.apache.poi.ss.usermodel.Cell cell = row.getCell(colIndex);
        if (cell == null) cell = row.createCell(colIndex);
        cell.setCellValue((double) value);
    }

    private String getCellString(Sheet sheet, int rowIndex, int colIndex) {
        Row row = sheet.getRow(rowIndex);
        if (row == null) return null;
        org.apache.poi.ss.usermodel.Cell cell = row.getCell(colIndex);
        if (cell == null) return null;
        if (cell.getCellType() == org.apache.poi.ss.usermodel.CellType.STRING) return cell.getStringCellValue();
        return null;
    }

    private void clearCell(Sheet sheet, int rowIndex, int colIndex) {
        Row row = sheet.getRow(rowIndex);
        if (row == null) return;
        org.apache.poi.ss.usermodel.Cell cell = row.getCell(colIndex);
        if (cell == null) return;
        cell.setBlank();
    }

    private static final int FORM26_TRANSPORT_COL_START = 13; // N列
    private static final int FORM26_TRANSPORT_COL_END   = 18; // S列

    private void removeMergedRegionsOverlapping(Sheet sheet, int firstRow, int lastRow, int firstCol, int lastCol) {
        for (int i = sheet.getNumMergedRegions() - 1; i >= 0; i--) {
            CellRangeAddress region = sheet.getMergedRegion(i);
            if (region.getFirstRow() <= lastRow && region.getLastRow() >= firstRow
                    && region.getFirstColumn() <= lastCol && region.getLastColumn() >= firstCol) {
                sheet.removeMergedRegion(i);
            }
        }
    }

    private String buildMethodLabel(String method, Integer distKm) {
        if (method == null || method.isEmpty()) return "";
        switch (method) {
            case "航空機": return "航空機";
            case "バス":   return "バス";
            case "電車":   return "電車";
            case "自家用車": {
                String d = (distKm != null) ? String.valueOf(distKm) : "    ";
                return "自家用車( " + d + " )㎞";
            }
            default: return method;
        }
    }

    // 交通手段を上段（row..row+1）、区間を下段（row+2）に分割して書き込む
    private void writeSplitTransportText(Sheet sheet, int row, String methodLabel, String route) {
        Workbook wb = sheet.getWorkbook();
        removeMergedRegionsOverlapping(sheet, row, row + 2, FORM26_TRANSPORT_COL_START, FORM26_TRANSPORT_COL_END);

        // 上段: row～row+1 結合 → 交通手段
        sheet.addMergedRegion(new CellRangeAddress(row, row + 1, FORM26_TRANSPORT_COL_START, FORM26_TRANSPORT_COL_END));
        Row r1 = sheet.getRow(row); if (r1 == null) r1 = sheet.createRow(row);
        org.apache.poi.ss.usermodel.Cell c1 = r1.getCell(FORM26_TRANSPORT_COL_START);
        if (c1 == null) c1 = r1.createCell(FORM26_TRANSPORT_COL_START);
        c1.setCellValue(methodLabel != null ? methodLabel : "");
        CellStyle s1 = wb.createCellStyle(); s1.cloneStyleFrom(c1.getCellStyle());
        s1.setAlignment(HorizontalAlignment.CENTER); s1.setVerticalAlignment(VerticalAlignment.CENTER);
        c1.setCellStyle(s1);

        // 下段: row+2, N:S 結合 → 区間
        sheet.addMergedRegion(new CellRangeAddress(row + 2, row + 2, FORM26_TRANSPORT_COL_START, FORM26_TRANSPORT_COL_END));
        Row r2 = sheet.getRow(row + 2); if (r2 == null) r2 = sheet.createRow(row + 2);
        org.apache.poi.ss.usermodel.Cell c2 = r2.getCell(FORM26_TRANSPORT_COL_START);
        if (c2 == null) c2 = r2.createCell(FORM26_TRANSPORT_COL_START);
        c2.setCellValue(route != null ? route : "");
        CellStyle s2 = wb.createCellStyle(); s2.cloneStyleFrom(c2.getCellStyle());
        s2.setAlignment(HorizontalAlignment.CENTER); s2.setVerticalAlignment(VerticalAlignment.CENTER);
        s2.setWrapText(true);
        c2.setCellStyle(s2);
    }

    private void ensureLabel(Sheet sheet, int rowIndex, int colIndex, String label) {
        String cur = getCellString(sheet, rowIndex, colIndex);
        if (cur == null || cur.trim().isEmpty()) writeSafe(sheet, rowIndex, colIndex, label);
    }

    // ===== 様式2-4 テンプレート丸の選択削除 =====

    private String classifyTemplateEllipse24(int row1, int localCol) {
        if (row1 == 7 && localCol >= 4 && localCol <= 7)   return "PROJECT:強化練習";
        if (row1 == 7 && localCol >= 11 && localCol <= 14) return "PROJECT:遠征試合";
        if (row1 == 10 && localCol >= 4 && localCol <= 7)   return "CATEGORY:成年男子";
        if (row1 == 10 && localCol >= 11 && localCol <= 14) return "CATEGORY:成年女子";
        if (row1 == 11 && localCol >= 4 && localCol <= 7)   return "CATEGORY:少年男子";
        if (row1 == 11 && localCol >= 11 && localCol <= 14) return "CATEGORY:少年女子";
        return null;
    }

    private void pruneTemplateEllipses24Side(Sheet sheet, int colOffset, Project project) {
        if (!(sheet instanceof org.apache.poi.xssf.usermodel.XSSFSheet)) return;
        org.apache.poi.xssf.usermodel.XSSFSheet xssfSheet = (org.apache.poi.xssf.usermodel.XSSFSheet) sheet;
        org.apache.poi.xssf.usermodel.XSSFDrawing drawing = xssfSheet.getDrawingPatriarch();
        if (drawing == null) return;

        int colMin = colOffset + 4;
        int colMax = colOffset + 17;

        String keepProject  = (project != null) ? "PROJECT:"  + project.getName()           : null;
        String keepCategory = (project != null) ? "CATEGORY:" + project.getTargetCategory() : null;

        org.openxmlformats.schemas.drawingml.x2006.spreadsheetDrawing.CTDrawing ctd = drawing.getCTDrawing();

        // 後ろから削除してインデックスずれを防ぐ
        for (int i = ctd.sizeOfTwoCellAnchorArray() - 1; i >= 0; i--) {
            org.openxmlformats.schemas.drawingml.x2006.spreadsheetDrawing.CTTwoCellAnchor anchor =
                    ctd.getTwoCellAnchorArray(i);
            int col1 = anchor.getFrom().getCol();
            int row1 = anchor.getFrom().getRow();

            if (col1 < colMin || col1 > colMax) continue;

            int localCol = col1 - colOffset;
            String label = classifyTemplateEllipse24(row1, localCol);
            if (label == null) continue;

            boolean keep = label.equals(keepProject) || label.equals(keepCategory);
            if (!keep) {
                ctd.removeTwoCellAnchor(i);
            }
        }
    }
}
