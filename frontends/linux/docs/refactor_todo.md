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
- [ ] Ensure all selection/navigation entry points go through one transition gate:
  - project select
  - card select
  - AI thread select
  - search result open
  - toolbox breadcrumb navigation
  - tool-driven card open
- [ ] Ensure loading/error states are transition states, not domain-empty states.
- [ ] Keep previous committed content visible until next commit is ready (all panes).

Recent progress:
- `CardsController.move_card_by_intent(...)` no longer triggers direct `load_selected_card.begin()` side effects after requesting selection.
- `CardsController.move_card_to_trash(...)` now uses centralized `MainController.reload_cards_for_selected_project()` instead of inlined `card_selection_requested(null)` + `show_project_overview()` flow.
- Card deselection now has a transition-owned project-overview path:
  - `SelectionIntentController.on_card_selection(...)` now routes `card_id == null` to `SelectionTransitionController.run_project_overview_selection(...)`.
  - `MainController.reload_everything_with_selection(...)` and `MainController.reload_cards_for_selected_project()` no longer directly call `show_project_overview()` after emitting `card_selection_requested(null)`.
  - `MainWindow.request_project_selection(...)` and `MainWindow.request_card_selection(...)` now trigger selection intent orchestration so controller-driven requests follow the same transition gate as widget-driven requests.

## Toolbox-Specific Remaining Work
- [ ] Add final toolbox-focused tests for atomic breadcrumb navigation:
  - no intermediate blank/placeholder states on valid-to-valid transitions
  - stale navigation responses cannot overwrite latest scope
  - fixed action row remains stable while content updates

## Hardening Tests (Phase C)
- [ ] Transition stale-drop tests:
  - late responses dropped for project/card/tool transitions
- [ ] No-intermediate-empty tests:
  - card A -> card B does not render `No card selected`
  - project P1 -> P2 does not clear to placeholder first
- [ ] Failed-transition retention tests:
  - previous committed content remains visible on failure
  - error/toast emitted without destructive UI reset

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
