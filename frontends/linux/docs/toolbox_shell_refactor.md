# Toolbox Shell Refactor

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
- `ToolScopeSnapshot get_scope_snapshot()`
- `async bool navigate_to_projects_root(uint seq)`
- `async bool navigate_to_project_root(string project_id, uint seq)`
- `async bool navigate_to_card(string card_id, uint seq)`

## Per-Tool Action Row Migration
- Flowboard: none.
- Connections: `Add Connection`, `Toggle Relations`.
- Resources: filter controls + CRUD buttons (move all top/bottom controls into action row).
- Terminals: terminal selector (and future `Copy to Card`).
- Trash: filter dropdown + `Empty Trash` (optional text filter later).
- Debug: `Clear` (and future `Copy to Card`).

## Navigation Behavior Rules
- Breadcrumb click starts a navigation transaction in `ToolboxNavigationController`.
- No immediate content/editor clearing.
- Show subtle loading state in breadcrumb/action rows while awaiting data.
- On success, swap to the new scope atomically.
- On failure, keep previous state and show error/toast.

## Acceptance Criteria
- Breadcrumb rendering/handling comes from one shared component.
- Tool controls remain visible while content scrolls.
- Clicking breadcrumb segments does not produce intermediate blank/incorrect states.
- Stale async responses never overwrite newer navigation state.
- Flowboard and Connections use the same shell behavior and contract.

## Implementation Plan
1. Add model + components (`NavigationBreadcrumbs`, `ToolActionBar`).
2. Introduce `ToolboxShell` with fixed header/action rows.
3. Add `ToolboxNavigationController` with sequence-based stale response dropping.
4. Migrate Flowboard and Connections to the tool adapter contract.
5. Move controls from Resources/Terminals/Trash/Debug into action row.
6. Remove legacy in-tool breadcrumb/header logic.
7. Validate against acceptance criteria and then expand to remaining tools.
