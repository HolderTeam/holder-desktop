# UI Principles (Historical)

This document is retained as historical context.
Active refactor tracking now lives in `docs/refactor_todo.md`.

## Core Model
1. Views emit intents, not business logic.
2. One owner per flow (coordinator/controller), no competing orchestrators.
3. App state is the source of truth.
4. State flows down into UI via controlled apply/render paths.
5. Async transitions are sequence-guarded; stale responses are dropped.

## Practical Rules
1. No direct widget-to-widget orchestration.
2. No valid-to-valid clear/refill flicker.
3. Keep previous committed UI visible until next commit is ready.
4. Distinguish true empty states from transition/loading states.

## Current Status (March 2026)
1. Strong progress:
   - `MainWindow` signal fanout has been extracted into binders/orchestrators.
   - Selection flows and key toolbox navigation paths run through transition controllers.
   - Multiple domains moved from view logic into controllers/services.
2. Still in progress:
   - Full renderer-from-state model for all panes.
   - Transition hardening tests for stale-drop and no-intermediate-empty guarantees.

## Next Priority
1. Finish state-first rendering boundaries per pane (`sidebar`, `editor`, `toolbox`, `ai`).
2. Complete toolbox adapter migration and remove remaining toolbox ad hoc policy.
3. Add transition-focused tests and lock behavior.
