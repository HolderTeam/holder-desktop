# Frontend Refactor TODO

This is the single working TODO for the current frontend refactor.
It consolidates:
- `UI_principles.md`
- `ui_state_transition_plan.md`
- `toolbox_shell_refactor.md`

## Guiding Rules (non-negotiable)
- [ ] Views emit intents; no business logic in views.
- [ ] One owner per async flow; no competing orchestrators.
- [ ] App state is source of truth; UI renders from committed state.
- [ ] No valid-to-valid clear/refill flicker.
- [ ] Sequence-guard async transitions; stale responses are dropped.

## Completed Foundation
- [x] Global transition primitives added:
  - `src/state/app_state.vala`
  - `src/controllers/app_transition.vala`
- [x] Window signal fanout extracted to binders/orchestrators.
- [x] Toolbox shell/header/action-row model implemented.
- [x] Project-scoped toolbox tools migrated to adapter contract.
- [x] Toolbox breadcrumb routing consolidated through controllers/orchestrators.
- [x] AI Catalog moved out of project toolbox into AI panel:
  - `src/views/ai_panel/catalog.vala` (`AiCatalogPanelView`)
- [x] Legacy in-tool shell header scaffolding removed.

## In Progress: State-First Rendering Boundaries
- [ ] Sidebar fully render-from-state (single committed apply path).
- [ ] Editor fully render-from-state (single committed apply path).
- [ ] Toolbox fully render-from-state (single committed apply path).
- [ ] AI panel fully render-from-state (single committed apply path).
- [ ] Remove remaining mixed ownership where transitions and domain controllers both commit UI-affecting state.

## In Progress: Transition Ownership Cleanup
- [x] Ensure all selection/navigation entry points go through one transition gate:
  - project select
  - card select
  - AI thread select
  - search result open
  - toolbox breadcrumb navigation
  - tool-driven card open
- [ ] Ensure loading/error states are transition states, not domain-empty states.
  - [x] Flowboard: pending context refresh keeps previously committed tiles visible (no loading-empty reset) (`src/controllers/flowboard.vala`, `tests/flowboard_controller_test.vala`)
  - [ ] Sidebar: transition loading/error state ownership audit + tests.
  - [ ] Toolbox tools: loading/error state ownership audit + tests.
  - [ ] AI panel: loading/error state ownership audit + tests.
- [ ] Keep previous committed content visible until next commit is ready (all panes).

## Transition Ownership: Completed Subtasks
- [x] `CardsController.move_card_by_intent(...)` no longer triggers direct `load_selected_card.begin()` side effects.
- [x] `CardsController.move_card_to_trash(...)` uses centralized `MainController.reload_cards_for_selected_project()`.
- [x] Card deselection routes through transition-owned project overview selection.
- [x] Controller-driven project/card selection requests go through `SelectionIntentOrchestrator`.
- [x] AI-thread selection uses common transition begin/finish flow.
- [x] Search selection request handling is centralized at `MainWindow.request_search_selection(...)` -> `SelectionIntentOrchestrator`.
- [x] `SelectionRequestController` now owns only explorer selections (project/card/AI thread).
- [x] Toolbox breadcrumb project navigation delegates to `SelectionIntentOrchestrator`.

## Toolbox-Specific Remaining Work
- [ ] Add final toolbox-focused tests for atomic breadcrumb navigation:
  - no intermediate blank/placeholder states on valid-to-valid transitions
  - stale navigation responses cannot overwrite latest scope
  - fixed action row remains stable while content updates

## Hardening Tests (Phase C)
- [ ] Transition stale-drop tests:
  - [x] `AppTransitionController`: stale-safe `commit_selection(...)` and `finish(...)` covered (`tests/app_transition_test.vala`)
  - [x] `SelectionTransitionController`: stale-safe `commit_selection(...)` and `finish_navigation_if_current(...)`, plus loading signal coverage (`tests/selection_transition_test.vala`)
  - [x] Add explicit late-response drop coverage for full project/card/tool transition flows.
    - [x] project flow: stale list-cards success/failure ignored (`tests/main_controller_test.vala`)
    - [x] card flow: stale load-selected-card success/failure ignored (`tests/main_controller_test.vala`)
    - [x] tool flow: stale serial refresh success/error ignored (`tests/trash_controller_test.vala`)
- [x] No-intermediate-empty tests:
  - [x] card A -> card B does not render `No card selected` (`tests/main_controller_test.vala`)
  - [x] project P1 -> P2 does not clear to placeholder first (`tests/main_controller_test.vala`)
- [x] Failed-transition retention tests:
  - [x] previous committed content remains visible on failure (`tests/main_controller_test.vala`)
  - [x] error/toast emitted without destructive UI reset (`tests/main_controller_test.vala`)

## Cleanup / Debt
- [ ] Remove obsolete comments/docs referring to pre-orchestrator paths.
- [ ] Prune dead compatibility shims and stale helpers introduced during migration.
- [ ] Update test names to match orchestrator/controller ownership language.

## Acceptance Criteria for This Refactor
- [ ] All major navigation flows are intent -> transition gate -> commit -> render.
- [ ] No visible valid-to-valid flicker in sidebar/editor/toolbox/AI panel.
- [ ] No stale async overwrite of newer committed selection/scope.
- [ ] Toolbox shell behavior is consistent across project-scoped tools.
- [ ] Transition and rendering behavior is locked by focused tests.

## Notes
- This TODO tracks active work only.
- Historical implementation detail remains in the original three docs.
