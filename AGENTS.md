# GTK Frontend — Purpose & Responsibilities

## Overview

The GTK frontend is a **local-first desktop thinking environment**, built with **GTK4 + libadwaita**, whose job is to provide a calm, native GNOME interface for:

* writing and organising notes
* planning projects
* interacting with local and external AI tools
* reviewing and reusing AI outputs as first-class artefacts

It is **not** a chat app, **not** a cloud client, and **not** an IDE.

The frontend is intentionally **thin**: it renders state, manages user interaction, and delegates all real logic (storage, indexing, AI, git, search) to a local backend service.

Status note:

- The responsibility split in this file is still broadly correct.
- Some older architecture notes later in this document describe an earlier shell and endpoint surface.
- For active implementation planning, treat this file plus `docs/FEATURE_PLAN.md` and `docs/refactor_todo.md` as the current guidance.

---

## Core UX Model

The application follows a **studio / workspace layout**:

### Left Sidebar (Primary Navigation)

* GNOME-native sidebar (`Gtk.StackSidebar`)
* Provides navigation between high-level app sections:

  * Home / Workspace
  * Recent
  * Projects
  * Search
* Styled entirely by libadwaita / system theme (no custom theming)

### Centre Area (Primary Working Surface)

This is where the user *thinks and writes*.

It supports **modes**, not panes:

* **Editor mode**

  * Free-form text / markdown writing
  * Default focus of the app

* **Corkboard mode**

  * Zoomed-out view of notes/cards using `Gtk.GridView`
  * Used for planning, structuring, and rearranging ideas
  * Nautilus-like visual language

Switching modes is conceptualised as **zooming in/out**, not switching apps.

### Right Panel (AI Assistant)

* Optional, toggleable panel
* Slides in from the right
* Used to:

  * compose prompts
  * view local AI output
  * export prompts for cloud AIs
* AI output does **not** overwrite user text
* AI suggestions are captured deliberately by the user

### Bottom Panel (Toolbox)

* Optional, toggleable bottom drawer (~24 lines high)
* VS Code–style
* Intended for:

  * logs
  * model status
  * terminal-like output
  * future advanced tools
* Must never dominate the main editor area

---

## AI Interaction Philosophy

The frontend treats AI as a **tool**, not a conversational partner.

Key principles:

* The **user types in the main editor**
* The **AI panel generates prompts**
* Cloud AI interaction is **manual and explicit** (copy/paste)
* Pasted AI responses become **new notes/cards with metadata**
* All AI responses are stored with provenance:

  * source (local / ChatGPT / Claude / etc.)
  * timestamp
  * associated project/note

The frontend must never assume:

* network access
* API keys
* user consent to send data externally

---

## Project & Resource Awareness

The frontend allows projects to reference external context:

* local folders
* git repositories
* documents
* URLs

These are treated as **project resources**, not opaque files.

The frontend:

* displays and manages these references
* allows the user to explicitly include them in AI context
* does not automatically ingest or upload content

---

## Technical Boundaries

The GTK frontend **does**:

* render UI
* manage navigation and layout
* capture user intent
* send requests to the local backend
* display results

The GTK frontend **does not**:

* run AI models
* index files
* manage git directly
* perform search or embeddings
* store primary data (beyond transient UI state)

All of that belongs to the backend.

---

## Design Principles

* **Native first**: use libadwaita widgets, no custom theming
* **Calm UI**: minimal visual noise, no novelty views
* **Explicit actions**: nothing “magical” or implicit
* **Keyboard-friendly**: navigation and toggles must be accessible
* **Local-first**: cloud is optional and user-mediated
* **Progressive disclosure**: power features stay hidden until needed

---

## Non-Goals

* No graph visualisation gimmicks
* No real-time cloud chat integrations
* No attempt to replace IDEs
* No Electron / web tech
* No “AI knows best” behaviour

---

## Long-Term Direction (Informative, Not Binding)

* The same backend may later support:

  * TUI clients
  * editor plugins
  * mobile frontends
* The GTK frontend should remain a **best-in-class desktop client** for thoughtful, AI-assisted work.

## Frontend Architecture Notes (GTK4 / libadwaita)

This application uses **GTK 4** with **libadwaita** and is intentionally designed to work on **Ubuntu 24.04 (libadwaita 1.5)** as the minimum supported baseline.

The UI structure prioritizes:

* stability on current LTS distros,
* minimal dependency churn,
* and easy future migration to newer libadwaita navigation widgets when available.

### High-level layout

The window is structured as:

```
Adw.ApplicationWindow
└── Adw.OverlaySplitView          (root shell)
    ├── Sidebar (left navigation)
    └── Main content area
        ├── Header bar (always visible)
        └── Main page stack
```

Key points:

* The **left sidebar is purely navigational**.
* The **header bar and toolbar controls are persistent** and do not disappear when navigating.
* The sidebar switches *pages*, not the entire window.

### Navigation model

Navigation is implemented using:

* `Gtk.Stack` as the **navigation model**
* `Gtk.StackSidebar` as the **controller view**

The sidebar **controls a dedicated `main_stack`**, whose pages represent top-level sections (e.g. Home / Recents / Projects).

**Important invariant**
The sidebar **must never control the root container**.
Only the central page stack is switched. This prevents navigation from “erasing” the entire UI.

### Workspace page

The primary working UI lives inside a single stack page called `"workspace"`.

That page contains:

* A persistent header bar
* A central `Gtk.Stack` (Editor / Corkboard views)
* A right-hand AI panel (sidebar) controlled independently
* A bottom toolbox revealed via `Gtk.Revealer`

This structure allows:

* multiple independent panels,
* nested navigation,
* and feature growth without restructuring the window.

### Sidebar widget choice

We intentionally use **`Gtk.StackSidebar`**, not a newer libadwaita sidebar widget.

Reasons:

* libadwaita ≤ 1.8 does **not** provide a stable, drop-in adaptive sidebar controller
* Ubuntu 24.04 ships libadwaita 1.5
* The newer Adwaita sidebar APIs land later and are not yet a clean replacement

Styling is handled via:

```vala
sidebar.add_css_class("navigation-sidebar");
```

This gives the correct GNOME / Adwaita appearance without requiring newer APIs.

### Future migration

When targeting newer runtimes (e.g. Ubuntu 26.04 or Flatpak):

* The navigation **model** (`Gtk.Stack` + page IDs) should remain unchanged
* Only the **sidebar view widget** may be swapped out
* No core UI logic should depend on a specific sidebar implementation

### Design principles

* Prefer **explicit structure over cleverness**

---

## Restart Playbook (Current State)

Last updated: February 17, 2026

### Repo + Build Conventions

* Git repo root for desktop client work: `.`
* Build directory: `build`
* One-command build script: `make.sh`

Build command:

```bash
./make.sh
```

Binary path:

* `build/holder-desktop`

Run command:

```bash
./build/holder-desktop
```

### Required Ubuntu Packages

Core packages currently used by the client:

* `meson`
* `ninja-build`
* `valac`
* `libgtk-4-dev`
* `libadwaita-1-dev`
* `libgtksourceview-5-dev`
* `libsoup-3.0-dev`
* `libgee-0.8-dev`
* `libjson-glib-dev`

### Current Linux Client Architecture

Source layout:

* `main.vala` - thin entrypoint
* `src/app.vala` - `Adw.Application`
* `src/views/window.vala` - main window composition
* `src/views/workspace_pane.vala` - editor/toolbox shell
* `src/views/ai_panel*.vala` - AI panel UI
* `src/views/toolbox*.vala` - toolbox shell and tools
* `src/controllers/*.vala` - orchestration, transitions, feature controllers
* `src/services/api_client/*.vala` - authenticated Holder API client surface
* `src/services/discovery.vala` - backend discovery via `holder.json`
* `src/models/*.vala` - typed app models
* `src/state/*.vala` - app state and activity state

### Backend Discovery + Auth

Client reads server info from:

* `~/.local/share/holder/server/holder.json`

Expected fields:

* `bind`
* `port`
* `auth_token`
* (plus metadata like `pid`, `api_version`, `server_version`)

All requests use:

* `Authorization: Bearer <auth_token>`

### API Endpoints Wired Right Now

* `GET /health`
* `GET /projects`
* `POST /projects`
* `GET /cards?project_id=...`
* `POST /cards`
* `GET /cards/{card_id}`
* `PATCH /cards/{card_id}`
* `GET /search/cards`
* `GET /ai/capabilities`
* `GET /ai/status`
* `POST /ai/runner/pull`
* `GET /ai/runner/pull/{job_id}`
* `POST /ai/runner/retry`
* `GET/PUT /ai/local-models/config`
* `GET/POST /ai/threads`
* `GET/PATCH/DELETE /ai/threads/{thread_id}`
* `POST /ai/runs`
* `GET /ai/runs`
* recovery token export/import routes

### Current Behavior Implemented

* App boots and discovers Holder backend from `holder.json`
* Health check on startup
* First-run bootstrap:
  * if no projects exist, create `"My Project"`
* Sidebar project list + card list
* Editor loads selected card content
* New card button creates an initial card
* Debounced autosave (~900ms) sends card updates to backend
* Card search is wired
* AI panel status/model pull/config UI is wired
* AI threads and `/ai/runs` streaming are wired
* Toolbox is now a substantial surface, including Connections and Recovery Key flows
* Selection and rendering flow is transition-gated through controllers/orchestrators rather than direct widget-to-widget mutation

### Known Gaps / Next Work

* AI message/provenance UI is still incomplete
* AI search UI is still incomplete
* Resource management UI remains partial
* Multi-runner runner management UI is planned but not implemented yet
* Frontend-side recovery drafts for failed saves are planned in `holder-daemon/docs/ASYNC_PLAN.md` but not implemented yet
* Connections refresh containment work in `holder-daemon/docs/ASYNC_PLAN.md` is still relevant
* Flatpak packaging/app-id integration still needs a pass

### Notes For Future Edits

* Keep frontend thin: no local persistence/indexing logic in client
* Backend contract reference:
  * `holder/openapi.yaml`
  * `holder/docs/CLIENTS.md`
  * `holder/docs/SWAGGER_TUTORIAL.md`
* Active frontend work tracking:
  * `docs/FEATURE_PLAN.md`
  * `docs/refactor_todo.md`
