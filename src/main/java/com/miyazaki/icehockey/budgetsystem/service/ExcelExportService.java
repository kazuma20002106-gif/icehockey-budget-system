package com.miyazaki.icehockey.budgetsystem.service;

import com.miyazaki.icehockey.budgetsystem.mapper.ExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectParticipantMapper;
import com.miyazaki.icehockey.budgetsystem.mapper.ProjectSummaryExpenseMapper;
import com.miyazaki.icehockey.budgetsystem.model.Expense;
import com.miyazaki.icehockey.budgetsystem.model.Project;
import com.miyazaki.icehockey.budgetsystem.model.ProjectParticipant;
import com.miyazaki.icehockey.budgetsystem.model.ProjectSummaryExpense;
import com.miyazaki.icehockey.budgetsystem.model.User;
import com.miyazaki.icehockey.budgetsystem.service.UserSettingService;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Font;
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
import java.util.List;

@Service
public class ExcelExportService {

    @Autowired private ProjectMapper projectMapper;
    @Autowired private ProjectSummaryExpenseMapper summaryMapper;
    @Autowired private ProjectParticipantMapper participantMapper;
    @Autowired private ExpenseMapper expenseMapper;
    @Autowired private UserSettingService userSettingService;

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

        // 右側専用: テンプレート由来のダミーデータを追加クリア
        if (colOffset > 0) {
            clearCell(sheet, 18, 17); // R19: 参加人員ダミー値 3
            clearCell(sheet, 18, 19); // T19: 名
            clearCell(sheet, 18, 34); // 参加人員 計の式 (R19C35)
            clearCell(sheet, 22, 17); // R23: 旅行雑費 日数ダミー値 2
            clearCell(sheet, 22, 19); // T23: 日
            clearCell(sheet, 22, 25); // 旅行雑費 単価 (R23C26)
            clearCell(sheet, 22, 30); // 旅行雑費 人数 (R23C31)
            clearCell(sheet, 22, 34); // 旅行雑費 日数 (R23C35)
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
                // 相方自動連行システム
                int id = projectIds.get(0);
                Project target = projectMapper.findById(id);
                Integer fiscalYear = target.getFiscalYear();
                List<Project> yearProjects = projectMapper.findByFiscalYearOrdered(fiscalYear);

                int position = 1;
                for (int i = 0; i < yearProjects.size(); i++) {
                    if (yearProjects.get(i).getId().equals(id)) {
                        position = i + 1; // 1-based
                        break;
                    }
                }

                Sheet newSheet = workbook.cloneSheet(templateIndex);
                workbook.setSheetName(workbook.getSheetIndex(newSheet), "2-4_" + id);

                if (position % 2 == 1) {
                    // 奇数回目: 左=対象, 右=空欄
                    populate24Side(newSheet, id, 0);
                    pruneTemplateEllipses24Side(newSheet, 0, projectMapper.findById(id));
                    clearSide24(newSheet, 17);
                    pruneTemplateEllipses24Side(newSheet, 17, null);
                } else {
                    // 偶数回目: 右=対象, 左=1つ前の活動
                    populate24Side(newSheet, id, 17);
                    pruneTemplateEllipses24Side(newSheet, 17, projectMapper.findById(id));
                    if (position >= 2) {
                        int prevId = yearProjects.get(position - 2).getId();
                        populate24Side(newSheet, prevId, 0);
                        pruneTemplateEllipses24Side(newSheet, 0, projectMapper.findById(prevId));
                    } else {
                        clearSide24(newSheet, 0);
                        pruneTemplateEllipses24Side(newSheet, 0, null);
                    }
                }
            } else {
                for (int i = 0; i < projectIds.size(); i += 2) {
                    int id1 = projectIds.get(i);
                    Integer id2 = (i + 1 < projectIds.size()) ? projectIds.get(i + 1) : null;

                    Sheet newSheet = workbook.cloneSheet(templateIndex);
                    workbook.setSheetName(workbook.getSheetIndex(newSheet), "2-4_" + id1 + (id2 != null ? "_" + id2 : ""));

                    populate24Side(newSheet, id1, 0);
                    pruneTemplateEllipses24Side(newSheet, 0, projectMapper.findById(id1));
                    if (id2 != null) {
                        populate24Side(newSheet, id2, 17);
                        pruneTemplateEllipses24Side(newSheet, 17, projectMapper.findById(id2));
                    } else {
                        clearSide24(newSheet, 17);
                        pruneTemplateEllipses24Side(newSheet, 17, null);
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
            writeSafe(sheet, 1, 0, "令和" + rYear + "年度　国スポ選手強化プロジェクト（①選手強化費）事業実施報告書");
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

        writeSafeNumeric(sheet, 20, 3 + colOffset, transportSum);
        writeSafeNumeric(sheet, 21, 3 + colOffset, accommodationSum);
        writeSafeNumeric(sheet, 22, 3 + colOffset, miscSum);

        if (colOffset == 0) {
            writeSafeNumeric(sheet, 17, 6, coachCount);
            writeSafeNumeric(sheet, 17, 12, playerCount);
        } else {
            writeSafeNumeric(sheet, 17, 23, coachCount);
            writeSafeNumeric(sheet, 17, 29, playerCount);
        }

        // 合計金額の強制上書き (R34C4 or R34C21, 0-based row=33)
        int total = transportSum + accommodationSum + miscSum
                + parkingCost + rentalCost + suppliesCost + serviceCost + compensationCost;
        writeSafeNumeric(sheet, 33, 3 + colOffset, total);

        // 記入責任者氏名・電話番号 (row=46, col=0 - 両側で共有)
        try {
            User activeUser = userSettingService.getActiveUser();
            if (activeUser != null) {
                String responsible = "記入責任者氏名（　" + activeUser.getName()
                        + "　）　　電話番号（　" + activeUser.getPhoneNumber() + "　）";
                writeSafe(sheet, 46, 0, responsible);
            }
        } catch (Exception e) {
            // ユーザー取得失敗時は空欄のまま
        }
    }

    public void exportForm25(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet(SHEET_25, projectIds, outputStream,
                (sheet, project, summary, participants) -> populate25(sheet, project, participants));
    }

    private void populate25(Sheet sheet, Project project, List<ProjectParticipant> participants) {
        // 年度数値 (R3C3, 0-based row=2 col=2)
        if (project.getEventDate() != null) {
            int fy = project.getFiscalYear() != null ? project.getFiscalYear() : project.getEventDate().getYear();
            writeSafeNumeric(sheet, 2, 2, getReiwaYear(fy));
        }

        // 宿泊あり判定（事業実施日・ヘッダー・参加者印字で共通使用）
        boolean hasAccommodation = participants.stream().anyMatch(p ->
                p.getExpense() != null && nz(p.getExpense().getAccommodationCost()) > 0);

        // 事業実施日: 令和X年Y月Z日 / 宿泊あり: ～W日 (R6C3, 0-based row=5 col=2)
        if (project.getEventDate() != null) {
            String eventDateText = formatJapaneseDate(project.getEventDate());
            if (hasAccommodation) {
                LocalDate endDate = project.getEventDate().plusDays(1);
                if (endDate.getMonthValue() == project.getEventDate().getMonthValue()) {
                    eventDateText += "～" + endDate.getDayOfMonth() + "日";
                } else {
                    eventDateText += "～" + endDate.getMonthValue() + "月" + endDate.getDayOfMonth() + "日";
                }
            }
            writeSafe(sheet, 5, 2, eventDateText);
        }

        // 宿泊対象者ヘッダーと参加者の〇印
        if (hasAccommodation && project.getEventDate() != null) {
            // 宿泊日ヘッダー (R8C8, 0-based row=7 col=7)
            LocalDate stayDate = project.getEventDate();
            writeSafe(sheet, 7, 7, stayDate.getMonthValue() + "月" + stayDate.getDayOfMonth() + "日");
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
            // 宿泊費が1円以上の参加者に〇 (旧: isAccommodated)
            boolean accommodated = p.getExpense() != null && nz(p.getExpense().getAccommodationCost()) > 0;
            writeSafe(sheet, r, 7, accommodated ? "〇" : "");
        }
        for (int r = startRow + participants.size(); r <= lastRow; r++) {
            clearCell(sheet, r, 1);
            clearCell(sheet, r, 3);
            clearCell(sheet, r, 6);
            clearCell(sheet, r, 7);
        }

        // 記入責任者氏名・電話番号 (R37C1, 0-based row=36 col=0)
        try {
            User activeUser = userSettingService.getActiveUser();
            if (activeUser != null) {
                String line = "記入責任者氏名（　" + activeUser.getName()
                        + "　）　電話番号（　" + activeUser.getPhoneNumber() + "　）";
                writeSafe(sheet, 36, 0, line);
            } else {
                writeSafe(sheet, 36, 0, "");
            }
        } catch (Exception e) {
            // ignore
        }
    }

    public void exportForm26(List<Integer> projectIds, OutputStream outputStream) throws Exception {
        exportMultiSheet(SHEET_26, projectIds, outputStream,
                (sheet, project, summary, participants) -> populate26(sheet, project, participants));
    }

    private void populate26(Sheet sheet, Project project, List<ProjectParticipant> allParticipants) {
        // 年度数値 (R3C10, 0-based row=2 col=9)
        if (project.getEventDate() != null) {
            int fy = project.getFiscalYear() != null ? project.getFiscalYear() : project.getEventDate().getYear();
            writeSafeNumeric(sheet, 2, 9, getReiwaYear(fy));
        }

        // タイトル
        String title = "選手強化費　　領収書１";
        if ("トップチーム".equals(project.getName())) {
            title = "トップチーム選手強化事業　領収書１";
        } else if ("ふるさと".equals(project.getName())) {
            title = "ふるさと選手強化事業　領収書１";
        }
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
            // 全交通手段を N:S x 3行ブロック結合に統一（航空機・自家用車・電車・バス等すべて）
            writeMergedTransportText(sheet, r, buildTransportDisplayText(method, distKm, route));

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
            writeMergedTransportText(sheet, r, "");
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
                writeSafe(sheet, 40, 27, "電話番号(" + activeUser.getPhoneNumber() + "　)");
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

        // 年度 (R2C8, 0-based row=1 col=7) - 先頭プロジェクトから令和年度を計算
        if (!projectIds.isEmpty()) {
            Project first = projectMapper.findById(projectIds.get(0));
            if (first != null && first.getEventDate() != null) {
                int fy = first.getFiscalYear() != null ? first.getFiscalYear() : first.getEventDate().getYear();
                writeSafeNumeric(sheet22, 1, 7, getReiwaYear(fy));
            }
        }

        writeSafeNumeric(sheet22, 15, 9, totalTransport);
        writeSafeNumeric(sheet22, 17, 9, totalAccommodation);
        writeSafeNumeric(sheet22, 21, 9, totalParking);
        writeSafeNumeric(sheet22, 23, 9, totalRental);
        writeSafeNumeric(sheet22, 25, 9, totalCompensation);
        writeSafeNumeric(sheet22, 27, 9, totalSupplies);
        writeSafeNumeric(sheet22, 29, 9, totalService);
    }

    // ===== テンプレートシート名 =====
    private static final String SHEET_24 = "様式２－４①②事業実施・実績報告書（選手強化費）";
    private static final String SHEET_25 = "様式２－５①事業別参加者名簿（選手強化）";
    private static final String SHEET_26 = "様式２－６①事業別領収書１（選手強化）";
    private static final String SHEET_22 = "様式２－２－１　事業別決算書（選手強化費）";

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
                    pruneTemplateEllipses24Side(s, 0, projectMapper.findById(id1));
                    if (id2 != null) {
                        populate24Side(s, id2, 17);
                        pruneTemplateEllipses24Side(s, 17, projectMapper.findById(id2));
                    } else {
                        clearSide24(s, 17);
                        pruneTemplateEllipses24Side(s, 17, null);
                    }
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

    private String buildTransportDisplayText(String method, Integer distKm, String route) {
        if (method == null || method.isEmpty()) return "";
        String label;
        switch (method) {
            case "航空機": label = "航空機"; break;
            case "バス":   label = "バス"; break;
            case "電車":   label = "電車"; break;
            case "自家用車": {
                String d = (distKm != null) ? String.valueOf(distKm) : "    ";
                label = "自家用車( " + d + " )㎞";
                break;
            }
            default: label = method; break;
        }
        return (route != null && !route.isEmpty()) ? label + "\n" + route : label;
    }

    private void writeMergedTransportText(Sheet sheet, int row, String text) {
        removeMergedRegionsOverlapping(sheet, row, row + 2,
                FORM26_TRANSPORT_COL_START, FORM26_TRANSPORT_COL_END);
        sheet.addMergedRegion(new CellRangeAddress(row, row + 2,
                FORM26_TRANSPORT_COL_START, FORM26_TRANSPORT_COL_END));
        Row r = sheet.getRow(row);
        if (r == null) r = sheet.createRow(row);
        org.apache.poi.ss.usermodel.Cell cell = r.getCell(FORM26_TRANSPORT_COL_START);
        if (cell == null) cell = r.createCell(FORM26_TRANSPORT_COL_START);
        cell.setCellValue(text);
        Workbook wb = sheet.getWorkbook();
        CellStyle style = wb.createCellStyle();
        style.cloneStyleFrom(cell.getCellStyle());
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        style.setWrapText(true);
        Font font = wb.createFont();
        font.setFontHeightInPoints((short) 14);
        style.setFont(font);
        cell.setCellStyle(style);
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
