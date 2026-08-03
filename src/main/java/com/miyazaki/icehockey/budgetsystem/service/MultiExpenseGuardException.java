package com.miyazaki.icehockey.budgetsystem.service;

/**
 * 既存活動の1人の参加者に対してExpenseが2件以上検出された場合に投げる例外（Cycle 21 P1-1）。
 * ProjectService.saveProject() 内の@Transactionalメソッドの中で投げることで、
 * 事業本体（projects）のinsert/updateを含めて確実に全件ロールバックさせる。
 */
public class MultiExpenseGuardException extends RuntimeException {
    public MultiExpenseGuardException(String message) {
        super(message);
    }
}
