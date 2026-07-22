# [Manual: Dex(P2) -> Air(P1 Review) / CC(P3)] Manual Restructure Plan

## 0. Purpose
Kazumax requested that tool development pause and that the team manual be reorganized first.

This plan is intended to prevent a repeat of Air's direct implementation overreach, while also making the manual reusable for projects other than the current budget tool.

The goal is not to add more rules. The goal is to split the rules into clear layers so each AI can quickly know:

- what must always be obeyed in any project
- what is specific to this project
- what is only the current handoff state
- what to output at completion

## 1. Current Problem
The current manuals mostly contain the right ideas, but their layers are mixed.

Observed issues:

- `AGENTS.md` includes both universal team rules and this project's exact dangerous file paths.
- `CURRENT_STATUS.md` is carrying too much history and older cycle detail.
- `WORKFLOW_RULES.md` is useful, but it should stay focused on handoff/output protocol rather than project-specific implementation risk.
- Air's direct-edit prohibition is present, but it is easier to obey if it is expressed as both a universal rule and a project-specific risk list.
- New chats may lose behavior if the startup prompt does not force all required rule files to be read.

## 2. Recommended Manual Layers

### A. `AGENTS.md` - Universal Top-Level Rules
Keep this file short and generic.

It should define:

- team roles: Kazumax, Air, Dex, CC
- mandatory startup declaration before work
- universal dangerous-task categories
- Air's default role as planner/reviewer, not implementer
- Dex's role as QA/reviewer
- CC's role as implementer
- completion rule: long output goes to files; chat gets only a short signal
- pointer to `docs/handoff/WORKFLOW_RULES.md`
- pointer to project-specific rules when present

It should not contain:

- exact Java file paths
- exact Excel templates
- exact mapper/schema paths
- old cycle history
- tool-specific temporary instructions

### B. `docs/handoff/WORKFLOW_RULES.md` - Universal Operation Rules
Keep this as the reusable handoff manual.

It should define:

- handoff file protocol
- tracking tags such as `[C1: Air(P1) -> Dex(P2)]`
- short chat / long file rule
- plus-alpha proposal rule
- completion checklist
- next-assignee text box rule
- what to do when a non-implementer edits code by mistake
- bootstrap text for new chats

This file can be reused in other projects with minimal edits.

### C. `docs/PROJECT_RULES.md` - Project-Specific Risk Rules
Create this new file for the budget-system project.

It should define:

- dangerous files and areas for this project
- Excel output / cell coordinate risk
- money and accounting calculation risk
- database and mapper risk
- template/resource contamination risk
- versioning rule for this project
- compile/test command expectations and the known Maven Wrapper caveat

Recommended first contents:

- `src/main/java/` changes are implementation changes and normally belong to CC.
- `src/main/resources/mapper/` changes are dangerous because they affect DB I/O.
- `src/main/resources/schema.sql` changes are dangerous because they affect persistence.
- `src/main/resources/*.xlsx` changes are dangerous because they affect official output forms.
- `src/main/java/com/example/budgetapp/service/ExcelExportService.java` is a high-risk file because it touches official Excel output, cell coordinates, and money totals.
- `src/main/resources/templates/` must be checked for accidental scripts or test files because it is copied into build resources.
- `application.properties` version updates are required when a completed task changes user-visible behavior or output.

### D. `docs/handoff/CURRENT_STATUS.md` - Current State Only
Keep this file short.

It should contain:

- current cycle/task name
- current phase
- next assignee
- files the next assignee must read
- stop conditions for the current phase
- Kazumax copy text for the next handoff

It should not contain:

- long history
- old review summaries
- full proposal text
- stale completed-cycle tables unless they directly affect the next task

### E. Legacy/Secondary Files
Do not delete these blindly. Decide their role during the manual cleanup.

- `AI_TEAM_WORKFLOW.md`: either turn into a short index pointing to `AGENTS.md` and `WORKFLOW_RULES.md`, or mark it as legacy if its rules are duplicated.
- `CLAUDE.md`: keep as CC-specific local guidance if needed, but it must not conflict with `AGENTS.md`.
- `.cursorrules`: keep only if Cursor is still actively used; otherwise mark as legacy/reference.

## 3. Universal Dangerous-Task Categories
Move the exact project file list out of `AGENTS.md`, but keep these generic danger categories there:

- money, accounting, totals, billing, financial output
- official documents, forms, reports, or generated files submitted externally
- database schema, migrations, persistence, or destructive data changes
- authentication, permissions, secrets, or external API calls
- build, deploy, release, or versioning behavior
- scripts or commands that delete, move, overwrite, or mass-edit files
- generated-resource directories where accidental files can enter the product

If a task touches any of these, Air must not directly implement unless Kazumax explicitly approves that exception after the startup declaration.

## 4. Air Overreach Rule
Add this rule in generic form to `WORKFLOW_RULES.md`:

If Air or another non-implementer directly edits code or dangerous project files by mistake:

1. stop further implementation
2. write a report under `docs/handoff/`
3. send to Dex for post-review
4. Dex decides OK/NG and writes rollback or continuation instructions
5. if correction is needed, the correction owner is CC unless Kazumax explicitly says otherwise

This keeps responsibility stable even when the original mistake was made by Air.

## 5. New Chat Bootstrap Text
After the restructure, the recommended reusable startup text should be:

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。
```

When Kazumax says "引継ぎもお願い", the AI should output this startup text together with the next-assignee-specific handoff text.

## 6. Implementation Order

Recommended order:

1. Air reviews this plan only for PM clarity and missing operational cases.
2. Air writes a short approval or adjustment note under `docs/handoff/`.
3. CC applies the manual edits.
4. CC reports changed files and any ambiguity under `docs/handoff/`.
5. Dex performs P4 review of the manual diff.
6. Kazumax uses the new bootstrap text in the next chat.

Air should not directly edit the manuals in this pass unless Kazumax explicitly approves Air as the manual editor for this specific task.

## 7. Acceptance Criteria
Manual cleanup is complete only when all are true:

- `AGENTS.md` is mostly generic and does not carry this project's exact implementation file list.
- `docs/PROJECT_RULES.md` exists and contains this project's dangerous areas.
- `docs/handoff/WORKFLOW_RULES.md` contains the short chat / long file rule, plus-alpha rule, next-assignee text box rule, and overreach recovery rule.
- `docs/handoff/CURRENT_STATUS.md` is short enough to be read at every startup without burying the current action.
- The new bootstrap text includes `docs/PROJECT_RULES.md` when present.
- There are no conflicting rules between `AGENTS.md`, `WORKFLOW_RULES.md`, `PROJECT_RULES.md`, `CLAUDE.md`, and `.cursorrules`.
- The manual makes clear that Air planning is safe, but Air implementation is exceptional and approval-gated.

## 8. Dex Recommendation
Proceed with this manual restructure before returning to tool implementation.

This should be treated as a process-safety task, not as ordinary app development. It does not require changing Java, templates, database files, Excel templates, or application version.

Recommended next assignee: Air for plan review, then CC for actual manual edits.

## 9. Kazumax Copy Text For Air
```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Airへ:
ツール本体の作業は一旦保留し、マニュアル整備を優先します。
Dexがマニュアル再整理の計画兼指示書を作成しました。
docs/handoff/P2_Dex_Instructions/manual_restructure_plan.md を熟読し、PM目線で安全性・運用しやすさ・不足ケースをレビューしてください。
今回はAirが直接実装・編集するのではなく、レビュー結果を docs/handoff/ に保存し、次にCCへ渡すべき修正方針を短くまとめてください。
```
