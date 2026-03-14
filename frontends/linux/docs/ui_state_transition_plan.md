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
    - Connections tool card opens now emit intent signals up to toolbox/window instead of mutating `Gtk.SingleSelection` directly.
    - AI thread selection notify path is now state-apply guarded to prevent programmatic apply loops.
    - Flowboard project tile activation now routes through `MainController.show_project_overview_for(project_id)` instead of mutating `Gtk.SingleSelection` directly inside flowboard controller logic.
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

## Acceptance Criteria
- Switching card A -> B never visibly renders `No card selected`.
- Switching project P1 -> P2 never clears editor/sidebar/toolbox to placeholder first.
- Breadcrumb navigation follows one transition path with stale response dropping.
- Late async responses cannot overwrite newer committed selection state.
