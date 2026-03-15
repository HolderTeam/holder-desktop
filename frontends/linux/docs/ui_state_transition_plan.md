# UI State Transition Plan

## Problem
- Project/card/tool navigation currently propagates through widget signals (`Gtk.SingleSelection` and view callbacks) plus async controller calls.
- During valid-to-valid navigation, UI often renders transient intermediate states (`No card selected`, temporary loading text, cleared lists).
- This causes visible churn/flicker and race risks (late async responses applying to stale selection).

## Goal
- Make app-level state the source of truth.
- Make widgets render from committed app state.
- Make navigation transitions atomic: keep prior committed view until next state is ready.

## Current Status
- Completed:
  - Added global transition primitives:
    - `src/state/app_state.vala` (`AppStateStore`)
    - `src/controllers/app_transition.vala` (`AppTransitionController`)
  - Wired `MainWindow` project/card selection and toolbox breadcrumb navigation through the global transition controller.
  - Added window-level guarded apply section (`with_state_apply`) to suppress signal loops during programmatic selection updates.
  - Removed old toolbox-only transition primitive (`src/controllers/toolbox_navigation.vala`).
- In progress:
  - Expanding transition ownership beyond project/card + breadcrumb paths (search/AI thread/flowboard context paths still mixed).
  - Recent progress:
    - Search-result activation now uses an explicit prepare/select/load transition path (no hidden controller-side selection+load side effects in the window intent path).
    - Search result selection now routes through `MainController.search_selection_requested` + window state apply helpers (removed direct `set_selected_index` mutations in controller/view intent handlers).
    - `MainController` no longer depends on `ISelectionState search_selection`; search selection is now fully view-applied from intent signals.
    - Removed controller-level project/card selection ignore flags; notify handlers now rely on the window-level `with_state_apply` guard only.
    - Project/card selection intent wiring now goes through `SelectionController` directly at the window layer; `MainController` pass-through methods were removed.
    - Connections tool card opens now emit intent signals up to toolbox/window instead of mutating `Gtk.SingleSelection` directly.
    - AI thread selection notify path is now state-apply guarded to prevent programmatic apply loops.
    - Flowboard project tile activation now routes through `SelectionIntentController.on_project_selection(...)` + `SelectionTransitionController` instead of mutating `Gtk.SingleSelection` directly inside flowboard controller logic.
    - Remaining window transition paths that loaded cards directly (`search-result-activation`, `tool-card-open`) now route through `SelectionController.on_card_selected()` so card-load entry is centralized at window selection intent level.
    - Added `SelectionTransitionController` to centralize navigation-loading and transition begin/commit/finish mechanics for selection-driven window transitions.
    - AI thread selection transition begin/commit/finish now runs through `SelectionTransitionController`, removing manual transition orchestration from `MainWindow`.
    - Shared card-open transition flow (used by search-result activation and tool-driven card open) now runs through `SelectionTransitionController.run_card_open_transition(...)`.
    - Toolbox breadcrumb navigation orchestration moved out of `MainWindow` into `ToolboxBreadcrumbController`; window now forwards breadcrumb intents plus UI callbacks only.
    - Explorer ID-to-selection resolution for project/card/AI-thread request paths now runs through `ExplorerSelectionController` instead of inline loops in `MainWindow`.
    - Search selection bounds/invalid handling now runs through `SearchSelectionController` rather than inline position checks in `MainWindow`.
    - Sidebar state-apply selection rendering (project/card/AI-thread) now runs through `SidebarSelectionRenderer`; `MainWindow` no longer carries inline ID scan/apply methods for those three lists.
    - Sidebar list data rendering now runs through `SidebarDataRenderer`; `MainWindow` no longer carries inline list-population loops for projects/cards/AI threads.
    - Selection request apply paths (project/card/AI-thread/search + select-card-by-id) now run through `SelectionRequestController`; direct `request_*_selection` methods were removed from `MainWindow`.
    - Selection intent transition logic (project/card/AI-thread/search-result/tool-card-open) now runs through `SelectionIntentController`; `MainWindow` now mostly extracts selected IDs and forwards.
    - Tool help title mapping and help markdown resource loading now run through `ToolHelpController`; `MainWindow` now only renders returned help content.
    - Internal-link parsing and project-card target resolution now run through `InternalLinkController`; `MainWindow` now only extracts current line/cursor context and handles UI reactions.
    - Find/replace validation and flow now run through `FindReplaceController`; `MainWindow` now only wires workspace events and hosts the low-level GtkSource operations adapter.
    - Recovery export/import flow decisions (project/pin/path validation, export/import orchestration, summary text formatting) now run through `RecoveryUiController`; `MainWindow` now primarily hosts dialogs and forwards user input/results.
    - Card email-share flow now runs through `ShareController`; `MainWindow` now only provides current card/editor text and wires toast/error signals.
    - Card append-from-terminal decision logic now runs through `CardAppendController`; `MainWindow` now only applies returned text to the editor.
    - Internal-link list extraction for Connections (`[[...]]` parse/dedupe) now runs through `InternalLinkController`; `MainWindow` now only forwards editor text and applies returned links.
    - Flowboard context async load sequencing/stale-drop now runs through `FlowboardContextController`; `MainWindow` no longer owns flowboard context request serial state.
    - Recovery dialog orchestration (`request PIN`, `save-file picker`, `import file + unlock`, `import summary dialog`) now runs through `RecoveryDialogAdapter`; `MainWindow` now wires toolbox actions and import completion only.
    - Window-level non-state actions (`About`, `Preferences`) now run through `WindowActionsAdapter`; `MainWindow` now forwards action signals and no longer builds those dialogs inline.
    - New-project dialog rendering now runs through `ProjectCreateDialogAdapter` and submission validation/privacy-mode mapping now runs through `ProjectCreateController`; `MainWindow` now only forwards create intent to `MainController`.
    - Card-action dialogs (`Move to Trash` confirm, `Create Linked Card` confirm) now run through `CardActionDialogAdapter`; `MainWindow` now forwards confirmed actions only.
    - Print action orchestration now runs through `PrintUiController` (error/toast mapping centralized); `MainWindow` now only provides current editor text + parent window.
    - Local-info action orchestration now runs through `LocalInfoUiController`; `MainWindow` now triggers the flow only.
    - Internal-link navigation decisioning (`open existing` vs `offer create` vs `ignore`) now runs through `InternalLinkController.decide_navigation(...)`; `MainWindow` now only provides cursor context/card snapshot and executes UI callbacks from the decision.
    - Flowboard project-overview tile activation now routes through `SelectionIntentController.on_project_selection(...)` + `SelectionTransitionController` instead of directly calling `MainController.show_project_overview_for(...)`.
    - Toolbox breadcrumb project-scope navigation now routes through `SelectionTransitionController.run_project_selection_without_flowboard(...)` + `SelectionController` instead of directly calling `MainController.show_project_overview()`.
    - Flowboard project-segment breadcrumb clicks now also run through the same project-selection transition path before switching flowboard scope.
    - `MainController` card-list reload/update flows now use explicit `card_selection_requested(...)` (and `has_card_summary(...)`) instead of internal `select_card_by_id(...)` mutation helper.
    - `MainController` project selection in reload flows now uses explicit `project_selection_requested(...)` + `has_project_summary(...)`; legacy `select_project_by_id(...)` and `show_project_overview_for(...)` were removed.
    - `MainController.reload_cards_for_selected_project()` is now data-only (no preferred-card parameter and no internal `load_selected_card.begin()` side effect); preferred-card selection/load is now explicit in caller flow (`reload_everything_with_selection(...)`, card move flow).
    - `SelectionIntentController` card-open flows now resolve card summaries via a resolver callback and request selection via signal; window no longer mutates selection through `SelectionRequestController.select_card_by_id(...)`.
    - `SelectionRequestController.select_card_by_id(...)` helper was removed; `SelectionRequestController` now contains request/apply methods only.
    - `CardsController` and `SearchController` now call `reload_selected_project_cards_data()` (pure data reload) instead of `reload_cards_for_selected_project()` side-effect flow.
    - `MainController` signal fanout wiring in `MainWindow` now runs through `MainControllerSignalBinder` + `IMainControllerSignalSink`; window constructor no longer owns the full inline connect block.
    - Window-level selection intent handlers (`project/card/ai-thread/search result/flowboard project/card-open`) now run through `SelectionIntentOrchestrator`; `MainWindow` now wires selection signals directly to orchestrator entry points.
    - AI panel and AI run bidirectional signal wiring now runs through `AiPanelEventOrchestrator` + `IAiPanelEventSink`; `MainWindow` no longer carries the inline AI panel event fanout block.
    - Toolbox event fanout wiring (breadcrumb navigation, flowboard/connect card-open, trash/move/new-card actions, share/recovery/terminal actions) now runs through `ToolboxEventOrchestrator` + `IToolboxEventSink`; `MainWindow` no longer carries the inline toolbox signal block.
    - Cross-controller feedback fanout (`find/share/card-append/recovery/print` toast/error propagation) now runs through `WindowFeedbackOrchestrator` + `IWindowFeedbackSink`; `MainWindow` no longer carries that inline feedback block.
    - Window action registration (`refresh/new-project/new-card/toggle-toolbox/find-replace/print/show-local-info/show-preferences/show-about`) now runs through `WindowActionBinder` + `IWindowActionSink`; `MainWindow` no longer carries the inline `construct` action block.
    - Sidebar/Workspace widget signal fanout now runs through `WindowSidebarEventBinder` + `ISidebarEventSink` and `WindowWorkspaceEventBinder` + `IWorkspaceEventSink`; `MainWindow` now handles these via internal intent methods rather than inline connect blocks.
    - Selection/editor/internal-link signal fanout now runs through `WindowSelectionEditorEventBinder` + `IWindowSelectionEditorEventSink`; `MainWindow` no longer carries inline selection-notify/editor-change/controller-key/gesture wiring.
    - Flowboard/context/card-store signal fanout now runs through `WindowFlowboardEventBinder` + `IWindowFlowboardEventSink`; `MainWindow` no longer carries inline flowboard event wiring.
    - Lifecycle and state signal fanout now runs through `WindowLifecycleEventBinder` + `IWindowLifecycleEventSink` and `WindowStateEventBinder` + `IWindowStateEventSink`; `MainWindow` no longer carries inline project-create error, close-request, app-state-changed, transition-loading, or paned-position wiring.
  - Consolidating all state commits so UI render changes are coordinated through one path.
- Not started:
  - Full renderer-from-state model (widgets fully driven from a committed state snapshot).
  - Transition-focused tests in this document’s Phase C.

## Design Principles
- Widgets emit **intents**, not state mutations.
- One coordinator owns async transition flow and stale response dropping.
- Distinguish domain-empty states from transition states.
- Never clear-to-empty for valid-to-valid transitions.

## Target Architecture

### 1) App State (single canonical state)
```text
AppState
  selection:
    project_id: string?
    card_id: string?
    ai_thread_id: string?
  data:
    projects: Project[]
    cards_by_project: Map<string, CardSummary[]>
    ai_threads_by_project: Map<string, AiThreadSummary[]>
    card_detail_by_id: Map<string, CardDetail>
  ui:
    toolbox_tool_id: string
    toolbox_scope: { tool_id, project_id?, card_id?, mode }
    search_query: string
    search_results: SearchCardResult[]
  transition:
    in_flight: bool
    seq: uint
    pending_selection: { project_id?, card_id?, ai_thread_id? }?
    pending_reason: string?
  status:
    status_text: string
    toasts: queue
    last_error: { title, details }?
```

### 2) Intents (events from views)
- `SelectProject(project_id)`
- `SelectCard(card_id)`
- `SelectAiThread(thread_id)`
- `NavigateBreadcrumb(tool_id, segment, project_id?, card_id?)`
- `OpenToolHelp(tool_id)`
- `SearchChanged(text)`
- `MoveCardToTrash(card_id)`

### 3) Coordinator (single async transition gate)
- Receives intents.
- Assigns `seq = ++counter`.
- Starts transition (sets pending + loading marker, but does not clear current committed content).
- Fetches required data.
- Commits only if `seq` is current.
- Drops stale results silently.

### 4) Renderer layer
- Reads `AppState` snapshot and updates widgets in a controlled section.
- During controlled apply, widget signal handlers are ignored.
- Widgets reflect state; they do not initiate state changes directly.

## Transition Rules

### Valid -> Valid selection
- Keep current editor/sidebar/toolbox content visible.
- Show subtle loading affordance (header spinner, busy cursor, etc.).
- Commit new state atomically when data arrives.

### Valid -> Empty (true domain empty)
- Show empty view only if target genuinely has no project/card.

### Error during transition
- Keep old committed content.
- Emit toast/error.
- Clear pending transition state.

## Immediate Refactor Scope (Phase A)
- Eliminate visual flicker for:
  - Project switch
  - Card switch
  - Toolbox breadcrumb project/card navigation

### Phase A.1: Centralize transition sequencing
- Replace toolbox-local sequencing with app-wide transition controller.
- Implemented:
  - `src/state/app_state.vala`
  - `src/controllers/app_transition.vala`

### Phase A.2: Normalize intent entry points
- `MainWindow` handlers convert widget callbacks into intents only.
- Remove direct `set_selected(...)` calls from tool/view code paths where possible.
- File targets:
  - `src/views/window.vala`
  - `src/views/toolbox.vala`
  - `src/views/sidebar.vala`

### Phase A.3: Add state apply guard
- Introduce `is_applying_state` guard in window-level rendering to suppress signal loops.
- Replace ad hoc suppression flags with one apply section wrapper.
- File targets:
  - `src/views/window.vala`
  - optional helper in `src/services/ui_adapters.vala`

### Phase A.4: Atomic selection commit path
- Project selection intent:
  1. start transition
  2. fetch cards/threads/resources as needed
  3. commit project+card+editor snapshot together
- Card selection intent:
  1. start transition
  2. fetch detail
  3. commit editor content + window title + status together
- File targets:
  - `src/controllers/main.vala`
  - `src/controllers/selection.vala` (or fold into transition controller)

## Phase B (Toolbox-wide consistency)
- Apply same transition model to:
  - Flowboard context loads
  - Connections scope hops
  - Search open-result navigation
  - AI thread selection

## Phase C (Hardening)
- Add transition-focused tests:
  - stale response dropping
  - no intermediate empty-state render for valid->valid
  - failed transition keeps previous committed view

## Current Code Notes
- Already good:
  - `src/controllers/app_transition.vala` sequence primitive exists and is wired for key navigation paths.
  - `MainController.show_project_overview()` already has serial stale checks.
- Still risky:
  - `MainWindow` remains orchestration-heavy with many direct signal fanouts.
  - Selection changes still originate from widgets in multiple places.

## Remaining Bypass Checklist
- [x] `MainWindow.open_card_with_transition(...)` no longer mutates sidebar selection via `SelectionRequestController.select_card_by_id(...)`; it now delegates to intent flow that resolves from controller state snapshot.
- [x] `SelectionRequestController.select_card_by_id(...)` removed.
- [x] `MainController.reload_cards_for_selected_project(...)` no longer triggers `load_selected_card.begin()` internally; card-load kickoff moved to explicit caller flows.
- [x] `CardsController` and `SearchController` no longer call `reload_cards_for_selected_project()` for side effects; they now use pure data reload path.
- [x] `MainWindow` signal fanout wiring has been extracted into binders/orchestrators (`MainControllerSignalBinder`, `AiPanelEventOrchestrator`, `ToolboxEventOrchestrator`, `WindowFeedbackOrchestrator`, `WindowActionBinder`, `WindowSidebarEventBinder`, `WindowWorkspaceEventBinder`, `WindowSelectionEditorEventBinder`, `WindowFlowboardEventBinder`, `WindowLifecycleEventBinder`, `WindowStateEventBinder`); `MainWindow` is now primarily composition + apply/render handlers.

## Acceptance Criteria
- Switching card A -> B never visibly renders `No card selected`.
- Switching project P1 -> P2 never clears editor/sidebar/toolbox to placeholder first.
- Breadcrumb navigation follows one transition path with stale response dropping.
- Late async responses cannot overwrite newer committed selection state.
