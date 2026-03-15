# Architecture

• Yes, your read is correct. You’re moving toward a strong UI architecture.

  For this app, these are good principles:

  1. Views emit intents, not business logic

  - Yes.
  - Views should capture user actions and forward them.
  - Keep business rules, async calls, retries, and sequencing out of widgets.

  2. One coordinator handles intents

  - Yes, with scope.
  - A single global coordinator can become too large; better is one app-level transition coordinator plus domain controllers.
  - Key rule: one owner per flow, no competing orchestrators.

  3. Central app state as source of truth

  - Yes.
  - Selection + loaded data + transition/loading state should be canonical.
  - Avoid widget-local “truth” that drifts from app state.

  4. Render from state (state down)

  - Yes.
  - UI should be a projection of current committed state.
  - This is what removes flicker/intermediate junk states.

  5. Render updates from one controlled path, not ad hoc everywhere

  - Yes.
  - You don’t need to redraw the whole app every time, but you do want one controlled apply pipeline.
  - Think “single render/apply boundary,” even if internally it updates sections.

  Why it feels faster now

  - You reduced transient clears and extra round-trips through widget state.
  - You dropped stale async results.
  - You made transitions atomic: keep old committed UI until next valid state is ready.

  If you keep these principles, the app will stay responsive and much easier to reason about as features grow.


• Yes. The next gains are clear and incremental.

  1. Remove selection-mutation helpers from flow logic

  - Finish deleting paths like “find item in widget selection then load.”
  - Resolve IDs from state/data stores, then emit intent.

  2. Move card-load side effects out of MainController.reload_cards_for_selected_project(...)

  - That method should reload data only.
  - Card/project load transitions should be owned by transition/intent controller only.

  3. Introduce a small NavigationIntent model

  - SelectProject, SelectCard, SelectThread, OpenToolHelp, etc.
  - One dispatcher receives these and routes to the right domain controller.

  4. Tighten the “state apply boundary”

  - Keep one apply_from_state(...) entry per major pane (sidebar/editor/toolbox/AI).
  - No direct widget updates outside those apply paths.

  5. Add stale-result guards everywhere async

  - Every async transition gets sequence ID check before commit.
  - Never let late responses overwrite newer state.

  6. Add transition tests (high value)

  - Valid->valid should never render empty intermediate UI.
  - Stale response drop test.
  - Error keeps previous committed UI test.

  7. Keep views dumb

  - Views: signals + rendering only.
  - Controllers/services: orchestration, rules, API calls, mapping.
