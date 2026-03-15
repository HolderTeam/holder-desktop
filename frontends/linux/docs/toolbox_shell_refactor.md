# Toolbox Shell Refactor

## Status
- This refactor is active and partially complete.
- It is now governed by the global transition architecture in:
  - `frontends/linux/docs/ui_state_transition_plan.md`
- Scope remains toolbox-specific; app-wide state migration is tracked in the global doc.

## Problem
- Breadcrumb behavior is duplicated across tools and mixed with tool-specific logic.
- Tool controls are embedded in scrollable content, so they scroll away.
- Navigation updates are not transactional; intermediate states flash (`Loading...`, `No card selected`) before final data arrives.

## Goals
- Provide one shared breadcrumb component for all tools.
- Hoist tool-specific controls into a fixed action row (non-scrolling).
- Make navigation updates transactional and stale-safe to remove visual flashing.
- Keep toolbox navigation semantics consistent across tools.

## Non-Goals
- Re-designing tool feature behavior itself.
- Changing backend APIs for this phase.
- Introducing cross-project graph/link features.
- Replacing entire app state architecture in this document (handled by global plan).

## Alignment With Global Plan
- Use app-state transition rules from `ui_state_transition_plan.md`.
- Toolbox breadcrumb navigation must follow intent -> coordinator -> commit flow.
- Avoid direct widget-driven clear/refill transitions.
- Keep old committed content visible during valid-to-valid scope switches.

## Target Layout
`ToolboxShell` owns a 3-row layout:
1. Header row: tool switcher + breadcrumbs.
2. Action row: tool-specific controls.
3. Content row: tool content (only this row scrolls).

## New Components

### NavigationBreadcrumbs
- Pure view component.
- Renders `{Tool} > {Project} > {Card/Overview}`.
- Emits click signals only; no tool-specific branching.

### ToolActionBar
- Fixed, non-scrolling action host.
- Accepts a tool-provided widget (or empty state).
- Can show loading/busy affordance during navigation.

### ToolboxNavigationController
- Coordinates breadcrumb navigation.
- Uses monotonically increasing request sequence IDs.
- Applies results only if request ID is current (drop stale responses).
- Keeps current content/editor visible until replacement data is ready.

Status:
- Implemented via app-wide sequencing primitives:
  - `src/state/app_state.vala`
  - `src/controllers/app_transition.vala`
- Breadcrumb routing unified through a single `MainWindow` handler.
- Full coordinator ownership of toolbox navigation policy is still pending.

## Data Model

### ToolScopeMode
- `PROJECTS_ROOT`
- `PROJECT_ROOT`
- `CARD_FOCUS`

### ToolScopeSnapshot
- `tool_id`
- `tool_label`
- `project_id`
- `project_label`
- `card_id`
- `card_label`
- `scope_mode`
- `is_loading`

## Tool Adapter Contract
Each tool is exposed through a common adapter API:
- `Gtk.Widget get_content_widget()`
- `Gtk.Widget? get_actions_widget()`
- `ToolScopeSnapshot get_scope_snapshot(Project?, CardSummary?)`
- `async bool navigate_to_projects_root(string? selected_project_id)`
- `async bool navigate_to_project_root(string project_id)`
- `async bool navigate_to_card(string card_id)`

Status:
- Formal interface now exists: `src/views/toolbox/tool_adapter.vala` (`IToolShellAdapter`).
- Adapter implementations now cover project-scoped tools:
  - Flowboard
  - Connections
  - Resources
  - Terminals
  - Trash
  - Debug
  - Git Sync
  - Sharing
  - Recovery Key
- `ToolboxPane` now uses adapter snapshots/action-row resolution for migrated tools.
- `AI Catalog` is intentionally global-scoped and remains outside the project-tool adapter path.

## Per-Tool Action Row Migration
- Flowboard: none.
- Connections: `Add Connection`, `Toggle Relations`.
- Resources: filter controls + CRUD buttons (move all top/bottom controls into action row).
- Terminals: terminal selector (and future `Copy to Card`).
- Trash: filter dropdown + `Empty Trash` (optional text filter later).
- Debug: `Clear` (and future `Copy to Card`).

Status:
- Completed for Connections, Resources, Terminals, Trash, Debug.
- Flowboard intentionally has no action row controls.

## Navigation Behavior Rules
- Breadcrumb click starts a navigation transaction in `ToolboxNavigationController`.
- No immediate content/editor clearing.
- Show subtle loading state in breadcrumb/action rows while awaiting data.
- On success, swap to the new scope atomically.
- On failure, keep previous state and show error/toast.

Status:
- Partially implemented.
- Loading indicator wiring exists (`ToolShell` / `ToolActionBar`).
- Stale dropping exists for key project-overview path.
- Still needs full coordinator-managed coverage across all toolbox navigation paths.

## Acceptance Criteria
- Breadcrumb rendering/handling comes from one shared component.
- Tool controls remain visible while content scrolls.
- Clicking breadcrumb segments does not produce intermediate blank/incorrect states.
- Stale async responses never overwrite newer navigation state.
- Flowboard and Connections use the same shell behavior and contract.

Progress:
- 1 and 2 are complete.
- 3 is improved but not complete in all paths.
- 4 is functionally complete for project-scoped tools (adapter contract implemented + wired).
- 5 is complete.

## Implementation Plan
1. Add model + components (`NavigationBreadcrumbs`, `ToolActionBar`).
2. Introduce `ToolboxShell` with fixed header/action rows.
3. Add `ToolboxNavigationController` with sequence-based stale response dropping.
4. Migrate Flowboard and Connections to the tool adapter contract.
5. Move controls from Resources/Terminals/Trash/Debug into action row.
6. Remove legacy in-tool breadcrumb/header logic.
7. Validate against acceptance criteria and then expand to remaining tools.

## Completed
- 1 complete.
- 2 complete.
- 3 partially complete (sequence + loading + unified breadcrumb routing).
- Flowboard project-card project-overview hops now also route through selection intent + transition controller (no direct `MainController.show_project_overview_for(...)` call from `MainWindow` flowboard signal path).
- Toolbox breadcrumb project segment now routes through selection transition + selection controller (no direct `MainController.show_project_overview()` call from breadcrumb controller).
- 4 complete for project-scoped tools (`ToolboxPane` consumes adapter contract for all project tools; `AI Catalog` remains global).
- 5 complete.
- 6 partially complete (done for Trash; remaining cleanup in other tools is minor).
- Toolbox card-open events (Flowboard, Connections, breadcrumb card segment) now route through `SelectionIntentOrchestrator` in `ToolboxEventOrchestrator`, removing the `MainWindow` callback handoff.
- Breadcrumb project-level navigation now runs on a single transition sequence (no nested transition calls), with current-sequence checks before scope UI application.

## Remaining (Toolbox Scope)
1. Ensure all breadcrumb/tool-scope async branches are stale-safe.
2. Final toolbox-focused tests for atomic navigation rendering behavior.

## Remaining Toolbox-Specific Checklist
- [x] Replace `MainWindow` callback-based `open_card_with_transition(...)` handoff with toolbox-owned intent orchestration (`ToolboxEventOrchestrator` -> `SelectionIntentOrchestrator`).
- [x] Remove remaining toolbox->window widget-selection coupling used for card open (`SelectionRequestController.select_card_by_id(...)` path).
- [x] Formalize tool adapter interface (`get_actions_widget`, `get_content_widget`, `get_scope_snapshot`) and migrate project-scoped toolbox tools.
- [ ] Keep breadcrumb/tool action rows fixed while proving no tool-specific header logic remains in content widgets.

## Deferred To Global Plan
- App-wide selection/app-state ownership migration.
- Unifying non-toolbox transitions under one global transition coordinator.
- Broader renderer/apply-state guard pattern across window/sidebar/editor/AI.
