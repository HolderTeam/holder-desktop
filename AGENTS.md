# GTK Frontend — Purpose & Responsibilities

## Overview

The GTK frontend is a **local-first desktop thinking environment**, built with **GTK4 + libadwaita**, whose job is to provide a calm, native GNOME interface for:

* writing and organising notes
* planning projects
* interacting with local and external AI tools
* reviewing and reusing AI outputs as first-class artefacts

It is **not** a chat app, **not** a cloud client, and **not** an IDE.

The frontend is intentionally **thin**: it renders state, manages user interaction, and delegates all real logic (storage, indexing, AI, git, search) to a local backend service.

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
* Keep navigation and layout **separable**
* Avoid tying app logic to transient GNOME UI trends
* Optimize for *maintainability over novelty*

If something looks “more manual” than a newer widget would allow, that is intentional.

### Ubuntu Development

sudo install libgtksourceview-5-dev libgee-0.8-dev
