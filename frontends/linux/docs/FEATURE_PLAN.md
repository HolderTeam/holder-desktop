# Holder Linux Frontend Feature Plan

Date: February 19, 2026
Scope: `frontends/linux` client using backend contracts in `holder/openapi.yaml` and `holder/docs/CLIENTS.md`.

## 1) Source Of Truth

Backend/API authority:

- `holder/openapi.yaml`
- `holder/docs/CLIENTS.md`
- `holder/docs/SWAGGER_TUTORIAL.md`
- `holder/docs/ROADMAP_AI.md`

Frontend constraints:

- GTK4 + libadwaita on Ubuntu 24.04 baseline
- Thin client: no direct DB/project-file writes
- All persistence/indexing/AI execution belongs to Holder backend

## 2) Product Goals

- Fast local writing workflow for projects and cards.
- First-class AI workflow with clear provenance and local-first behavior.
- Stable GNOME-native UX with explicit user actions.
- Full recoverability from backend state (restarts, reconnects, refresh).

## 3) Information Architecture

Window structure:

1. Top shell:
- Header bar (global app actions)
- Search row

2. Main content frame below top shell:
- Left sidebar (navigation/state lists)
- Center workspace (card editor and search results)
- Right panel (AI Assistant + AI Status tabs)

Sidebar sections:

- Projects
- Cards
- AI Threads

Right panel tabs:

- Assistant (default)
- Status (runtime/diagnostics/model onboarding)

## 4) Feature Areas

### A) Bootstrap + Session

Purpose:

- Discover running backend and validate compatibility.

Endpoints:

- `GET /health`
- read `holder.json` (`bind`, `port`, `auth_token`, versions)

UI elements:

- Status line in sidebar
- blocking startup state in editor area
- reconnect/refresh action

Done:

- implemented

### B) Project Management

Purpose:

- list/create/select/update/delete projects.

Endpoints:

- `GET /projects`
- `POST /projects`
- `GET /projects/{project_id}`
- `PATCH /projects/{project_id}`
- `DELETE /projects/{project_id}`

UI elements:

- project list view
- create project dialog
- project settings sheet/dialog (future)
- project delete confirmation (future)

Status:

- list + create done
- update/delete pending

### C) Card Workspace

Purpose:

- create/select/edit/search cards with autosave.

Endpoints:

- `GET /cards?project_id=...`
- `POST /cards`
- `GET /cards/{card_id}`
- `PATCH /cards/{card_id}`
- `DELETE /cards/{card_id}`
- `POST /cards/{card_id}/restore`

UI elements:

- card list in sidebar
- markdown editor in center
- autosave indicator
- create card action
- card trash/restore actions (future)

Status:

- core flow done
- trash/restore UI pending

### D) Search

Purpose:

- find cards and AI messages quickly.

Endpoints:

- `GET /search/cards`
- `GET /search/ai`

UI elements:

- top search entry
- search results page
- result activation back into editor/thread
- filter toggle cards vs AI (future)

Status:

- card search done
- AI search pending

### E) AI Onboarding + Runtime Status

Purpose:

- expose model/runtime readiness and model pull flow.

Endpoints:

- `GET /ai/capabilities`
- `GET /ai/status`
- `POST /ai/runner/pull`
- `GET /ai/runner/pull/{job_id}`
- `GET /ai/runner/pull/{job_id}/events` (optional for richer progress)
- `POST /ai/runner/retry`
- `GET/PUT /ai/local-models/config` (global Fast/Strong/Deep controls)

UI elements:

- right panel Status tab
- installed/recommended model display
- pull buttons
- pull progress list
- periodic polling when active pulls exist

Status:

- done (polling + pull actions implemented)
- router config UI pending

### F) AI Threads + Assistant

Purpose:

- conversational assistant flow anchored to project and thread.

Endpoints:

- `GET/POST /ai/threads`
- `GET/PATCH/DELETE /ai/threads/{thread_id}`
- `POST /ai/runs` (SSE stream)
- `GET /ai/runs?project_id=...` / `?thread_id=...`
- `GET /ai/runs/{run_id}`
- `GET /ai/runs/{run_id}/events`

UI elements:

- AI thread list in sidebar
- Assistant tab with:
  - transcript/output view
  - prompt input
  - send action
  - new thread action
- optional run metadata strip (model, provider, status, fallback)

Status:

- thread list/create wired
- `/ai/runs` streaming wired
- run history browser pending

### G) AI Messages + Provenance

Purpose:

- treat AI outputs as first-class artifacts with provenance and linking.

Endpoints:

- `GET/POST /ai/messages`
- `POST /ai/messages/capture`
- `GET/PATCH/DELETE /ai/messages/{message_id}`
- `POST /ai/messages/{message_id}/restore`
- `GET/POST/DELETE /ai/messages/{message_id}/links`
- `GET /ai/messages/{message_id}/backlinks`

UI elements:

- message list within selected thread
- metadata chips (source/provider/model/timestamp)
- manual capture dialog (paste prompt/response + provenance)
- links inspector (future)

Status:

- pending

### H) Resources

Purpose:

- attach project resources (repos/files/urls/docs) as explicit context.

Endpoints:

- `GET/POST /resources`
- `PATCH/DELETE /resources/{resource_id}`

UI elements:

- project resources panel/page
- create/edit/delete resource forms
- include/exclude in run context controls

Status:

- pending

### I) Trash + Recovery

Purpose:

- soft-delete visibility and restore workflows.

Endpoints:

- `GET/DELETE /trash`
- `DELETE /trash/{type}/{id}`
- `POST /cards/{card_id}/restore`
- `POST /ai/messages/{message_id}/restore`

UI elements:

- trash page with type filters
- restore and permanent delete actions
- project-scoped empty trash action

Status:

- pending

### J) Cloud Provider Configuration

Purpose:

- manage provider API keys and enable/disable routes.

Endpoints:

- `GET /ai/providers/catalog`
- `GET /ai/providers/credentials`
- `PUT /ai/providers/credentials`
- `DELETE /ai/providers/credentials/{provider}`

UI elements:

- provider catalog/settings page
- credential entry dialogs with secure handling
- enabled/configured status badges

Status:

- pending

## 5) Required UI Components (GTK/libadwaita)

- `Adw.ApplicationWindow`
- `Adw.OverlaySplitView` for left sidebar shell and right AI panel within workspace
- `Adw.HeaderBar` for top app actions only
- `Gtk.ListView` + `Gtk.SignalListItemFactory` for projects/cards/threads/results
- `GtkSource.View` for card editing
- `Gtk.SearchEntry` for search
- `Gtk.Stack` + `Gtk.StackSwitcher` for center modes and right-panel tabs
- `Gtk.TextView` for assistant transcript/prompt
- `Adw.MessageDialog` for create/edit confirmations
- `Adw.ToastOverlay` for transient feedback
- `GAction` (`SimpleAction`) + accelerators for keyboard-first flow

## 6) UX Rules

- AI panel must be below top shell and only split the workspace content area.
- AI output never silently overwrites card content.
- Every backend error must be visible (toast + status text), no silent no-op.
- Long-running actions should expose in-flight state and disable duplicate submits.
- Selection state should survive refreshes when IDs still exist.

## 7) Implementation Phases

## Phase 1 (Now - near complete)

- bootstrap/session, projects/cards basics, autosave
- card search
- AI status + model pulls
- AI threads sidebar
- assistant prompt + `/ai/runs` SSE stream

Remaining in phase:

- polish assistant transcript rendering (separate system/meta lines)
- explicit send-busy UI and cancellation strategy

## Phase 2

- AI message persistence views (`/ai/messages`)
- run history browser (`/ai/runs`, `/ai/runs/{id}`, `/events`)
- AI search (`/search/ai`)
- thread metadata editing

## Phase 3

- resource management UI (`/resources`)
- trash/recovery UI (`/trash`, restore endpoints)
- cloud provider credentials/catalog UI

## Phase 4 (Advanced)

- local model config UI (`/ai/local-models/config`)
- policy trace visualization for cloud runs
- compact/quality reason visualization from run metadata

## 8) Testing Plan

Unit tests (GLib.Test):

- text/title formatting helpers
- SSE parser and event dispatch helpers (to add)
- response parsing for nullable/optional JSON fields

Integration/manual checks:

- startup discovery failure and recovery
- project/card create/edit/autosave cycle
- AI pull flow + status polling
- `/ai/runs` stream handling across success/fallback/failure
- restart app and verify state reconstruction from backend

## 9) Open Questions To Decide Early

1. Assistant transcript source of truth:
- Keep temporary client transcript only, or immediately hydrate from `/ai/messages` for every selected thread?

2. Message capture policy:
- Use `/ai/messages/capture` for all manual edits/imports by default?

3. Default AI mode:
- For now, always `mode=auto` unless user explicitly chooses provider/model?

4. Left-sidebar density:
- Should AI threads show recency snippets, not just title + updated time?

5. Right-panel behavior:
- Keep panel sticky per project, or global toggle state only?

## 10) Immediate Next Tickets

1. Persist assistant transcript from `/ai/messages` when selecting thread.
2. Send flow: append streamed assistant result into message list and refresh thread messages.
3. Add run history view and event replay for selected run.
4. Add AI search mode (`/search/ai`) with open-message/thread behavior.
