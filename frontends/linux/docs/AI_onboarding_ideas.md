# AI Onboarding interface

We need to design an implement a way for users to setup local and cloud models to assist with writing and organising cards.

## Backend

Current backend AI support (from holder-daemon) is:

  Routing and Scope

  - AI routes are under authenticated /ai/* endpoints (except static catalog files).
  - Request dispatch covers: status/capabilities/router config, providers/credentials, runs, runner pull, threads, messages.
  - Static catalog is also available unauthenticated as /ai_catalog.yaml and /ai_catalog.json.

  Local Models (runtime)

  - Local runtime is LocalModelRunner (currently Ollama-oriented).
  - Exposes runner health + installed models + pull jobs:
      - GET /ai/capabilities
      - GET /ai/status
      - POST /ai/runner/retry
  - Model install/pull lifecycle:
      - POST /ai/runner/pull
      - GET /ai/runner/pull/{job_id}
      - GET /ai/runner/pull/{job_id}/events (SSE)

  Cloud Models

  - Cloud providers/models are loaded from config/ai_catalog.yaml (models.runtime, provider_defaults, Models.Cloud).
  - Supported provider API kinds:
      - chocolatefactory_generative_language
      - generic_chat
      - generic_responses
      - mechatropic_messages
  - Supports provider ordering, cost tiers, limits (rpm/tpm/rpd), cooldown policy, and summary-refresh/compaction config.
  - Uses HTTPS API calls with auth modes:
      - API key query param
      - Bearer header
      - Header key

  Provider Config + Credentials

  - Catalog and effective config:
      - GET /ai/providers/catalog
  - Provider enable/disable flags:
      - GET /ai/providers/settings
      - PUT /ai/providers/settings
      - DELETE /ai/providers/settings/{provider}
  - API credentials:
      - GET /ai/providers/credentials (masked preview)
      - PUT /ai/providers/credentials
      - DELETE /ai/providers/credentials/{provider}
  - Credentials are persisted in DB (ai_provider_credentials) and provider toggles in DB (ai_provider_settings).

  Router Config (global + per-project)

  - GET /ai/router/config?project_id=...
  - PUT /ai/router/config with scope=global|project, optional router_model.
  - Effective router model resolves project override > global > auto.

  Runs / Inference

  - POST /ai/runs starts inference and streams SSE (run_started, progress, chunk, fallback, done, failed).
  - GET /ai/runs?project_id=... or ?thread_id=...
  - GET /ai/runs/{run_id}
  - GET /ai/runs/{run_id}/events (SSE replay/live stream)
  - Run records persist prompt/context/mode/router/chosen model/status/errors/policy trace.

  Mode behavior

  - If local runner is available and no explicit cloud provider is requested: uses local path.
  - If local runner unavailable, or provider is explicitly requested: uses cloud path.
  - Cloud path includes multi-model attempts, quota checks, cooldown/backoff, and optional rolling summary compaction for long thread context.

  AI Threads + Messages

  - Threads CRUD:
      - GET/POST /ai/threads
      - GET/PATCH/DELETE /ai/threads/{thread_id}
  - Messages CRUD + soft-delete/restore + capture:
      - GET/POST /ai/messages
      - GET/PATCH/DELETE /ai/messages/{message_id}
      - POST /ai/messages/{message_id}/restore
      - POST /ai/messages/capture
  - Messages and runs can be linked to project/thread/card context.

  Important gaps / caveats for frontend onboarding

  - No OAuth-style credential flow; frontend must collect/store raw API keys via credentials endpoints.
  - No dedicated “test credential” endpoint; validation is effectively through real run attempts.
  - Local runtime abstraction exists, but practical implementation is Ollama-centric.
  - Cloud keys are DB-stored in this backend path (not keyring-backed like project privacy keys).

## Onboarding

I’d design this as a **guided setup flow on first use**, backed by a **persistent AI settings surface** after onboarding. Your backend already has the right primitives, so the UI job is mostly about turning “many technical options” into “one or two good choices.”

Given your current layout, I’d avoid making onboarding a separate big page. It fits better as a **stateful AI side panel flow** inside the existing right-hand AI panel, with the Catalog and Status tabs doing most of the heavy lifting.

## Core UX principle

The user should never have to answer “local or cloud?” up front.

Instead, the UI should:

1. detect what’s possible on this machine,
2. recommend a default setup,
3. let them add cloud access if they want more power,
4. make it obvious what is active now.

So the experience becomes:

* **Step 1:** “We checked your machine”
* **Step 2:** “Here’s the best local model you can install”
* **Step 3:** “Optionally add a cloud provider”
* **Step 4:** “Choose default behavior”
* **Step 5:** “You’re ready”

That is much less intimidating than exposing providers, router config, credentials, scopes, pull jobs, and model catalogs immediately.

## Recommended information architecture

I’d split the UI into three layers.

### 1. First-run onboarding

A short wizard that appears the first time a user opens AI, or when no usable AI path exists.

### 2. Persistent AI settings

A proper settings view users can revisit:

* Local models
* Cloud providers
* Default routing
* Per-project override

### 3. Inline operational status

Inside the normal assistant panel:

* current active route
* current model/provider
* install progress
* missing-key warnings
* fallback messages

## Best onboarding flow

## Step 1: Machine detection and recommendation

This should be the first screen.

Use Caste classification and `/ai/capabilities` + `/ai/status` to show a friendly summary like:

* **Your device:** Mid-range laptop
* **Recommended local models:** Small / medium
* **Can run locally:** Yes
* **Cloud support:** Optional with API key

This step should not dump raw technical hardware data unless the user expands details.

The important part is the recommendation card. Something like:

* **Recommended local setup**

  * Fast and private
  * Works offline after install
  * Best for everyday writing and brainstorming

* **Recommended cloud setup**

  * Stronger models
  * Requires API key
  * Best for larger reasoning tasks

Then offer two main actions:

* **Install recommended local model**
* **Set up cloud provider**

And one subtle third option:

* **Skip for now**

## Step 2: Local model install

This should feel like an app install, not a backend operation.

From your backend, this maps cleanly to:

* `POST /ai/runner/pull`
* `GET /ai/runner/pull/{job_id}`
* `GET /ai/runner/pull/{job_id}/events`

UI-wise, I’d show model cards from the catalog, filtered by Caste category.

Each card should include only:

* model name
* speed rating
* quality rating
* RAM/VRAM suitability
* approximate size/download
* “recommended” badge if it matches the machine class

Actions:

* **Install**
* **Recommended**
* maybe **Why this model?**

Once install begins, switch to a job-progress view:

* downloading
* verifying
* ready

Use SSE events to animate progress in place. Do not push users to a different screen.

Important: since the runtime is Ollama-ish, don’t expose “Ollama” unless necessary. Say “Local model runtime” or “Local AI engine,” then tuck technical detail under an advanced section.

## Step 3: Cloud provider setup

Because there is no OAuth and no test endpoint, this needs a careful UI.

This screen should be explicit but calm:

* “Connect a cloud provider with an API key”
* “Keys are stored in the app database”
* “Validation happens on first use”

Show provider cards sourced from `/ai/providers/catalog`.

Each provider row/card should have:

* provider name
* supported model families
* auth type hidden unless advanced
* status badge:

  * Not configured
  * Configured
  * Disabled

Primary action:

* **Add API key**

On click, open a compact form:

* API key field
* optional endpoint/base URL only if the provider kind needs it
* enable toggle after save

Since you can’t truly validate before use, after save I’d show:

* **Saved**
* **Will be verified on first request**

That avoids fake certainty.

Also show a tiny warning:

* “Cloud requests may incur provider charges”

## Step 4: Choose default behavior

This is where your router config becomes human-friendly.

Do not expose “router model” first. Expose **behavior presets**:

* **Prefer local**

  * use installed local models when possible
  * fall back to cloud only if chosen explicitly or local unavailable

* **Prefer cloud**

  * use configured cloud models by default

* **Ask each time**

  * show a route picker in the composer

* **Automatic**

  * let the system choose based on availability and project settings

Under the hood this maps to your global/project router config and provider settings, but the UI language should be about behavior, not router internals.

Then add an advanced expander:

* global default
* project override
* router model
* provider priority order

That keeps power without scaring normal users.

## Step 5: Ready state

When onboarding is done, show a summary:

* Local model: Installed / not installed
* Cloud provider: Connected / not connected
* Default mode: Prefer local / prefer cloud / ask each time

Then the CTA:

* **Start chatting**
* maybe **Open AI settings**

## How this should map into your current right panel

Your current tabs are:

* Assistant
* Status
* Catalog

That’s actually a good basis.

I’d use them like this:

### Assistant

Normal chat UI, but with a compact setup banner when AI is not ready:

* “Finish AI setup to start chatting”
* button: **Set up AI**

Once ready, show a small route badge above the composer:

* Local · Mistral 7B
* Cloud · Provider X · Model Y
* Auto

And let the user click it to switch.

### Status

Operational screen, not onboarding.

Show:

* local runtime health
* installed models
* active pull jobs
* provider connection state
* recent run failures/fallbacks

This tab is ideal for power users and debugging.

### Catalog

Discovery/setup screen.

Show:

* recommended local models for this machine
* available cloud providers
* model comparison
* install buttons

So onboarding can actually be a guided overlay that drives the user across these tabs, rather than creating a whole separate subsystem.

## Strong recommendation: separate “simple mode” and “advanced mode”

Your backend is already rich enough that the frontend could become too technical.

For most users, the only choices should be:

* install recommended local model
* add cloud API key
* choose default behavior

Everything else should be under Advanced:

* provider ordering
* cooldown policy
* limits
* summary compaction
* project router override
* raw provider enable/disable

That will make the product feel much more polished.

## Important UI states you need

These are the states I’d explicitly design for.

### 1. No local runtime, no cloud keys

Show:

* “No AI configured yet”
* primary actions:

  * install local runtime/model if possible
  * add cloud provider

### 2. Local runtime available, no model installed

Show:

* “Local AI is available, but no model is installed”
* recommended install card

### 3. Local model installed, no cloud keys

Show:

* “You’re ready with local AI”
* optional cloud upsell for stronger models

### 4. Cloud key saved, not yet validated

Show:

* “Connected, pending first-use verification”

### 5. Provider configured but disabled

Show:

* “Configured but turned off”
* enable toggle

### 6. Pull in progress

Show:

* progress bar
* download size if known
* live event log hidden behind details

### 7. Pull failed

Show:

* friendly explanation
* retry button using `/ai/runner/retry` or restart pull
* expandable technical error

### 8. Run fallback occurred

Since your run SSE exposes fallback, surface that gracefully:

* “Primary model unavailable, switched to backup”
  Not scary, just informative.

## Suggested UI components

A few reusable pieces would help a lot.

### Recommendation card

For the top recommended local model or cloud provider.
Includes:

* title
* why it’s recommended
* one main CTA

### Capability summary strip

A compact header:

* Device class
* Local runtime status
* Installed models count
* Cloud providers connected

### Provider row

Shows:

* provider name
* configured/not configured
* enabled/disabled
* edit/delete

### Route badge / picker

Lives near the prompt box.
Lets the user choose:

* Auto
* Local
* specific cloud provider/model

### Pull job panel

A single live progress component tied to SSE.

## What not to do

A few things I’d avoid.

Do not start by asking the user to choose from a long model list.

Do not expose raw backend concepts like:

* generic_chat
* generic_responses
* mechatropic_messages
* rpm/tpm/rpd
  unless the user enters advanced settings.

Do not make provider setup look “verified” at save time, since you can’t actually validate it.

Do not mix project-level routing choices into first-run onboarding unless the user is already inside a project and the choice clearly applies there.

## Suggested API-to-UI mapping

A clean mapping could be:

* `/ai/capabilities`
  for local runtime availability and machine-level setup hints

* `/ai/status`
  for installed models, health, active runtime state

* `/ai/providers/catalog`
  to populate cloud setup and model/provider discovery

* `/ai/providers/settings`
  for provider enable/disable toggles

* `/ai/providers/credentials`
  for saved/masked key state

* `/ai/runner/pull` + SSE
  for local install flow

* `/ai/router/config`
  for default behavior and project override

That gives you a very understandable frontend model:

* **Can I run local AI?**
* **What can I install?**
* **What cloud providers can I connect?**
* **What should the app prefer by default?**

## My preferred first-run script

If I were designing the exact sequence, it would be:

1. User opens AI
2. Panel says: “Set up AI in under a minute”
3. App checks capabilities/status
4. Show recommended local model card
5. Optional secondary card: “Connect cloud AI with API key”
6. User installs local model
7. Live progress
8. Success state
9. Ask for default behavior:

   * Prefer local
   * Ask each time
10. Done

Then later, in Settings/Catalog, they can add cloud providers.

That path keeps first-run friction low and gets the user to value quickly.

## One product decision that matters

Decide whether you want onboarding optimized for:

* **privacy/offline-first**
* or **best quality fast**

If CardApp is trying to feel personal and on-device, default the onboarding to:

* **Install local model**
* cloud is optional

If it’s trying to feel powerful immediately, default to:

* **Connect cloud provider**
* local is a bonus

From what you described, and because you already have Caste plus local catalog suggestions, I’d lean **local-first with optional cloud augmentation**.

## My concise recommendation

Use a **local-first guided setup** in the existing AI panel:

* Assistant = normal use
* Status = health/debug
* Catalog = install/setup/discovery

And make onboarding a 4-step guided overlay:

* detect machine
* recommend/install local model
* optionally add cloud API key
* choose default routing behavior

That will let the backend complexity stay powerful without forcing the user to understand it.

If you want, I can turn this into a concrete wireframe spec with exact panel layouts and component states.

Here’s a concrete **wireframe-level UI spec** for the AI onboarding and settings flow in CardApp, shaped around your current layout.

I’ll assume the current three-tab right panel stays:

* **Assistant**
* **Status**
* **Catalog**

And that onboarding is a **guided mode layered into that panel**, not a separate full-screen wizard.

# 1. Main UX shape

## First-time experience

When the user opens the AI panel and AI is not yet usable, the **Assistant** tab should not show a dead empty chat area. It should show a setup state.

### Assistant tab, unconfigured state

Top area:

* title: **AI setup**
* subtext: “Use local models on your computer, connect cloud APIs, or both.”

Main body:

* primary recommendation card
* optional secondary card
* small “advanced setup” link

Footer:

* **Set up AI**
* or if you want to skip the intro cards, just start the guided sequence immediately

The important thing is that the user sees an opinionated recommendation, not an empty panel.

---

# 2. Guided onboarding flow

I’d make onboarding a **5-step state machine** inside the AI panel, probably in the Assistant tab with the other tabs still visible.

The panel width in your screenshot is fairly tight, so each step must be compact and single-purpose.

## Step 1: Detect machine and recommend setup

### Layout

Top:

* heading: **Set up AI**
* progress indicator: `1 of 5`

Body:

* capability summary box
* recommendation cards

### Capability summary box

Fields:

* **Computer class:** Mini / User / Developer / Workstation / Rig
* **Local AI:** Available / Not available
* **Cloud AI:** Available with API key
* **Recommended profile:** Lightweight local / Standard local / Cloud-first / Hybrid

This should come from:

* Caste classification
* `/ai/capabilities`
* `/ai/status`

### Recommendation cards

You want two large cards max.

#### Card A: Recommended local setup

Contents:

* title: **Use AI on this computer**
* subtitle: “Private, fast, works after install”
* badge: **Recommended**
* summary:

  * best for drafting, note help, brainstorming
  * no API key needed
* CTA: **Install recommended model**

#### Card B: Optional cloud setup

Contents:

* title: **Connect a cloud provider**
* subtitle: “Stronger models, requires API key”
* summary:

  * useful for deeper reasoning
  * may incur provider charges
* CTA: **Add provider**

Footer buttons:

* **Continue**
* **Skip for now**

### Behaviour

If local runtime is unavailable:

* card A changes to:

  * **Local AI not available**
  * “Install the local runtime to use on-device models”
  * CTA: **Open local setup**
    or, if you do not want runtime setup in-app yet:
  * “Local AI is not currently available on this system”
  * CTA becomes disabled or informational

---

## Step 2: Local model selection

This should live mostly off the **Catalog** data model, but in a guided layout.

### Layout

Top:

* heading: **Choose a local model**
* progress indicator: `2 of 5`

Body:

* one recommended card at top
* “other suitable models” below

### Recommended model card

Fields:

* model name
* quality label: Basic / Good / Strong
* speed label: Fast / Balanced / Slower
* approximate size
* recommended for this machine because…
* install button

Example content:

* **Llama 3.2 3B**
* Good for quick drafting and note assistance
* Fast on this machine
* Approx. 2–3 GB
* **Install**

### Other model cards

Each compact row/card should show:

* model name
* size
* speed/quality tags
* install button

Do not show 20 models at once. Cap it at maybe 3–5 relevant ones, with:

* **Show more models**

### Filters

Tiny row above the list:

* **Recommended**
* **Fast**
* **Balanced**
* **More capable**

Not technical hardware filters. User-goal filters.

### Behaviour

When install starts:

* replace install button with progress bar + status text
* disable installing multiple models at once unless you really want concurrent pulls

Status text examples:

* Preparing…
* Downloading…
* Verifying…
* Ready

### Failure state

If pull fails:

* inline error box:

  * “Could not install this model”
  * reason if available
* buttons:

  * **Retry**
  * **Choose another model**
* details expander:

  * raw backend error

---

## Step 3: Cloud provider setup

This is the trickiest bit because of no OAuth and no true test endpoint.

### Layout

Top:

* heading: **Connect cloud AI**
* progress indicator: `3 of 5`

Body:

* short explanation
* provider list
* credential form area

### Intro text

“Cloud providers can offer stronger models. You’ll need to paste an API key. The key will be stored by the app and verified on first use.”

That wording is honest and clear.

### Provider list

Each provider row/card:

* provider name
* description
* configured state
* enabled state
* add/edit action

Compact layout:

**OpenAI-compatible**

* Strong general-purpose chat models
* Status: Not configured
* [Add key]

**Google / Gemini-like**

* Good multimodal and general reasoning
* Status: Configured
* Enabled
* [Edit] [Disable]

Use friendly names from catalog, not backend enums.

### Add/edit provider form

When selected, show a form below the provider row or in a modal sheet.

Fields:

* API key
* optional base URL if supported
* enable after saving checkbox
* optional nickname only if you think users need it

Buttons:

* **Save**
* **Cancel**

After save:

* show success state:

  * “Saved. Verification will happen on first use.”

### Important UI note

Do not show a green tick meaning “working” until there has been an actual successful run.

So provider states should be:

* **Not configured**
* **Configured**
* **Enabled**
* **Pending verification**
* **Working**
* **Error on last use**

That last one will be very useful.

---

## Step 4: Choose default behavior

This is where you humanise router config.

### Layout

Top:

* heading: **Choose how AI should work**
* progress indicator: `4 of 5`

Body:

* radio cards for behavior
* optional advanced section

### Behaviour cards

#### Option A: Prefer local

Text:

* “Use installed local models by default”
* “Private and works offline after install”

#### Option B: Prefer cloud

Text:

* “Use connected cloud providers by default”
* “Best when you want stronger models”

#### Option C: Ask each time

Text:

* “Show a route picker before sending”

#### Option D: Automatic

Text:

* “Let CardApp choose based on what’s available”

These map to router behaviour in the frontend, even if backend config remains a bit more granular.

### Advanced section

Collapsed by default.

Contents:

* global/project scope toggle
* router model dropdown if relevant
* provider priority ordering
* fallback policy summary
* long-thread compaction summary

That advanced section is for you and power users, not normal users.

---

## Step 5: Finish / ready state

### Layout

Top:

* heading: **AI is ready**
* progress indicator: `5 of 5`

Body:

* summary list

Example:

* Local model: **Llama 3.2 3B installed**
* Cloud provider: **None connected**
* Default mode: **Prefer local**

or:

* Local model: **None**
* Cloud provider: **OpenAI-compatible configured**
* Default mode: **Prefer cloud**

Buttons:

* **Start chatting**
* **Open AI settings**

This should drop the user straight into Assistant mode.

---

# 3. Persistent tab design after onboarding

Now the steady-state UI.

## A. Assistant tab

This is the everyday view.

### Top strip

A slim status strip above the thread area:

* route badge
* model/provider badge
* health indicator if needed

Example:

* **Local · Llama 3.2 3B**
* **Cloud · Anthropic · Sonnet**
* **Auto**

Make it clickable.

### Route picker behaviour

Clicking the badge opens a small popover:

Sections:

* **Automatic**
* **Local**

  * list installed local models
* **Cloud**

  * list enabled providers/models
* **Project default**
* **Global default**

This lets the user override without visiting settings.

### Empty thread state

Instead of blank black space:

* “Ask AI about this card, this project, or a general idea.”
* quick prompts:

  * Summarise this card
  * Help me plan this feature
  * Suggest next steps
  * Compare local vs cloud recommendations

### Unavailable state inside Assistant

If the user hasn’t set anything up:

* setup banner:

  * “AI is not configured yet”
  * button: **Set up AI**

If local install exists but is still downloading:

* banner:

  * “Model install in progress”
  * progress bar
  * button: **View progress**

### During a run

Show tiny metadata line above the assistant response:

* Running on Local · Llama 3.2 3B
* or Cloud · Provider X
* if fallback happens:

  * “Switched to backup model”

That gives great transparency.

---

## B. Status tab

This should be operational and slightly more technical.

I’d divide it into four stacked sections.

### Section 1: Current AI state

Fields:

* local runtime: Available / Unavailable / Error
* installed models count
* enabled cloud providers count
* default route: Prefer local / Prefer cloud / Automatic / Ask each time

### Section 2: Local runtime

Rows:

* runtime health
* runtime endpoint/version if you want
* installed local models
* active pull jobs

For installed models:

* model name
* ready state
* remove button maybe later

For active pull jobs:

* progress
* started time
* cancel/retry if supported

### Section 3: Cloud providers

For each provider:

* configured?
* enabled?
* last successful use
* last error
* edit credentials
* disable/delete

### Section 4: Recent runs

A small recent history:

* run status
* route chosen
* model chosen
* fallback yes/no
* timestamp

This is especially good because your backend persists run details and policy trace.

### Use of color/state

Keep it restrained:

* green: working
* amber: pending / fallback / partial
* red: failed
* neutral grey: unconfigured / disabled

---

## C. Catalog tab

This should be the “explore and manage” tab, not just raw catalog dumping.

I’d divide it into:

* Recommended
* Local models
* Cloud providers

### Recommended section

At the top:

* “Recommended for this computer”

Show 2–3 cards max:

* one recommended local model
* maybe one stronger local model if feasible
* one recommended cloud provider if no provider configured

### Local models section

Search and filters:

* search box
* filter pills:

  * Recommended
  * Installed
  * Fast
  * Balanced
  * Stronger

Each model card:

* name
* short description
* size
* speed/quality labels
* install state:

  * Install
  * Installing
  * Installed
  * Update maybe later

### Cloud providers section

Each provider card:

* provider name
* supported model families
* configured state
* enabled state
* button:

  * Add key
  * Edit
  * Enable/Disable

---

# 4. Recommended component inventory

Here are the actual reusable widgets I’d build.

## 1. `AiSetupBanner`

Used in Assistant when AI is unconfigured.

Props/state:

* mode: unconfigured / local-missing / pulling / ready
* primary CTA
* secondary CTA

---

## 2. `CapabilitySummaryCard`

Shows:

* computer class
* local runtime support
* recommendation text

Used in step 1 and maybe Catalog top section.

---

## 3. `ModelRecommendationCard`

Shows:

* model name
* description
* why recommended
* size
* speed/quality tags
* install button/progress

Used in onboarding and catalog.

---

## 4. `ProviderCard`

Shows:

* provider name
* description
* status badge
* add/edit/enable controls

Used in onboarding, catalog, status.

---

## 5. `RouteBadge`

Tiny chip above composer:

* Auto
* Local · model
* Cloud · provider/model

Clickable to open picker.

---

## 6. `PullJobProgressCard`

Shows:

* model name
* phase
* progress bar
* details expander
* retry state

Uses SSE.

---

## 7. `AiStateBadge`

Single small badge component for:

* Installed
* Installing
* Pending verification
* Enabled
* Disabled
* Error
* Fallback

You’ll use this everywhere.

---

# 5. State model you need in the frontend

You’ll save yourself pain if you define a clean frontend state shape rather than letting each tab improvise.

Something like:

```text
AiOnboardingState
- capabilities_loaded
- local_runtime_available
- local_models_installed[]
- recommended_models[]
- providers[]
- configured_credentials[]
- default_route_mode
- active_pull_jobs[]
- onboarding_step
- onboarding_complete
```

And for each provider:

```text
ProviderUiState
- provider_id
- display_name
- configured
- enabled
- pending_verification
- last_success_at
- last_error
```

For each model:

```text
ModelUiState
- model_id
- display_name
- installed
- recommended
- suitability
- install_state: idle|starting|pulling|verifying|ready|failed
- progress_percent?
- error?
```

That will make rendering much easier.

---

# 6. Specific UI copy suggestions

These matter because the feature is inherently technical.

## Good copy

* “Use AI on this computer”
* “Connect a cloud provider”
* “Recommended for this machine”
* “Saved. Verification will happen on first use.”
* “Use installed local models by default”
* “Switched to a backup model”

## Avoid

* “Configure provider credentials”
* “Select inference backend”
* “generic_chat”
* “runtime abstraction”
* “router model override”
  unless hidden in advanced sections

---

# 7. Edge-case screens you should explicitly design

These are easy to miss.

## No runtime installed

Show:

* local unavailable
* cloud still available
* maybe help link: “How local AI works”

## Catalog available but no suitable local model

Show:

* “This computer is better suited to cloud AI”
* recommend cloud provider instead

## Provider configured but invalid key

After first failed run:

* badge: **Error**
* message:

  * “This provider could not authenticate. Check your API key.”
* button:

  * **Edit credentials**

## Local runtime healthy but no models installed

Show:

* “Install a model to start using local AI”

## Multiple local models installed

Assistant badge should reflect the chosen default, not become confusing.
Maybe:

* **Local · Balanced**
  and inside picker:
* exact model names

## Per-project override exists

In the route picker:

* show small note:

  * “This project overrides the global AI setting”

That is enough for normal users.

---

# 8. My recommended exact onboarding default

Given your product, I’d set the default behaviour to this:

### If local runtime available and a recommended model is installable

push user toward:

* **Install recommended local model**

### After install

default route:

* **Prefer local**

### Then quietly offer cloud as an enhancement

not a requirement

This matches Holder/CardApp’s vibe much better than making API keys step one.

---

# 9. Suggested visual arrangement in your existing screenshot layout

Using your current right panel:

## Assistant tab, before setup

Top within right panel:

* `AI setup`
* small subtitle

Middle:

* one large recommended local card
* one medium cloud card underneath

Bottom:

* `Set up AI` button

---

## Assistant tab, after setup

Top:

* route badge row

Middle:

* thread messages

Bottom:

* prompt input
* maybe tiny status text like:

  * `Using local AI`

---

## Status tab

Vertical stacked cards:

1. Current state
2. Local runtime
3. Cloud providers
4. Recent runs

---

## Catalog tab

Scrollable:

1. Recommended
2. Local models
3. Cloud providers

That is enough; you do not need more tabs.

---

# 10. My strongest practical recommendation

Build the first version with only these user actions exposed:

* install recommended local model
* add/edit/delete cloud API key
* enable/disable provider
* choose default route mode
* choose route per thread/message from a small picker

Do **not** expose provider ordering, quotas, cooldowns, summary compaction, or router-model internals in v1 unless buried in Advanced.

Those can exist in backend and even in stored config, but the onboarding UI should stay very opinionated.

If you want, next I can turn this into a **GTK/libadwaita widget tree and screen-by-screen component list**, which might be more directly usable for your frontend.


Yes — for Gemini, the simplest and best onboarding path is still **API-key based**. Google intentionally designed **AI Studio + Gemini API** so that developers can just paste a key. That fits your app very well.

# Why Gemini is perfect for onboarding

Google’s **Gemini API via AI Studio** has:

* generous free tier
* simple API key model
* no billing required for small usage
* quick signup
* easy key generation

This means you can design a **“guided cloud setup”** that takes the user from nothing → working AI in under a minute.

That’s much better UX than forcing people to already have API keys.

---

# Recommended Gemini onboarding UX

Instead of just saying “paste an API key”, guide them.

## Step flow

```
Connect cloud AI
   ↓
Recommended provider: Gemini
   ↓
1. Open AI Studio
2. Create API key
3. Paste key here
4. Test connection
```

This dramatically increases success rate.

---

# Concrete UI design

Inside your **Cloud Provider setup step**.

### Gemini card

```
Gemini (Google)

✓ generous free tier
✓ fast responses
✓ good reasoning models

[ Connect Gemini ]
```

When clicked:

---

## Gemini setup panel

Title:

```
Connect Gemini
```

Instructions:

```
1. Open Google AI Studio
2. Create a free API key
3. Paste it below
```

Buttons:

```
[ Open AI Studio ]   (opens browser)
```

URL:

```
https://aistudio.google.com/app/apikey
```

Field:

```
API Key
[____________________________]
```

Buttons:

```
Save
Test connection
Cancel
```

---

# Backend behaviour

After user pastes key:

```
PUT /ai/providers/credentials
```

Provider: `gemini`

Then optionally:

```
POST /ai/providers/test
```

Minimal call:

```
GET https://generativelanguage.googleapis.com/v1beta/models?key=API_KEY
```

or equivalent.

Success → mark provider as verified.

---

# What the user experiences

Best case flow:

1️⃣ User opens AI panel
2️⃣ Sees **Recommended: Gemini free tier**
3️⃣ Clicks **Connect Gemini**
4️⃣ Clicks **Open AI Studio**
5️⃣ Creates key
6️⃣ Pastes key
7️⃣ Clicks **Save**

Done.

No account juggling, no OAuth redirects.

---

# Why not OAuth for Gemini

Google does support OAuth for many APIs, but for Gemini:

* API keys are the **intended dev flow**
* OAuth adds complexity
* desktop apps must implement browser redirects
* tokens expire and require refresh

That is **massively worse UX** for a local app.

---

# Very important UX improvement

When Gemini is connected, show **free tier messaging** clearly.

Example:

```
Gemini connected

Free tier available
Limits reset daily
Suitable for experimentation and light usage
```

This reassures users they won’t be billed accidentally.

---

# Also important: show model defaults

Once Gemini is configured, you can automatically enable something like:

```
gemini-1.5-flash
```

for chat.

Reason:

* fast
* cheap
* free tier friendly

Then users can switch later.

---

# How this fits your routing system

If Gemini is configured:

Default behaviour could be:

```
Prefer local
Fallback to Gemini
```

or

```
Automatic
Local → Gemini fallback
```

Your router already supports this nicely.

---

# Suggested “recommended cloud provider” logic

When onboarding runs:

```
if no providers configured:
    recommend Gemini
```

Because:

* easiest signup
* free tier
* widely available

Later you can add:

* OpenAI
* Anthropic
* OpenRouter
* etc.

But Gemini is the best first cloud provider.

---

# Catalog idea

In your **AI catalog YAML**, add metadata like:

```
providers:
  gemini:
    recommended: true
    onboarding_url: https://aistudio.google.com/app/apikey
    free_tier: true
    beginner_friendly: true
```

Then the frontend can highlight it automatically.

---

# One small UX trick that works really well

Add a **copy button** next to the key field label:

```
Paste your Gemini API key
[____________________________]

Need help?
[ Copy instructions ]
```

Which copies:

```
1. Visit https://aistudio.google.com/app/apikey
2. Click "Create API key"
3. Paste it into CardApp
```

People love this.

---

# My recommended onboarding hierarchy

Your onboarding screen should effectively show:

```
Recommended setup
────────────────────

Local AI
Install a model on this computer
Private and works offline

[ Install local AI ]

──────── or ────────

Cloud AI
Use Gemini's free tier

[ Connect Gemini ]
```

That makes the choice extremely obvious.

---

# My strongest suggestion

For v1 of Holder/CardApp AI onboarding:

**Highlight exactly two paths**

```
Install Local AI
Connect Gemini
```

Everything else goes under **More providers**.

This dramatically simplifies the UX.

---

If you want, I can also show you **a really nice trick used by Cursor, Ollama apps, and LM Studio to make local model installation feel like installing an app rather than downloading a giant model**, which improves perceived speed and reduces user anxiety.



The trick those apps use is **perception design**: they make the model install feel like installing an application rather than downloading a giant blob. That reduces user anxiety (“is this safe?”, “how long will this take?”, “did it freeze?”) and makes the UI feel faster even if the download time is identical.

You can reproduce the same effect fairly easily in your GTK/libadwaita UI.

---

# The “app install” pattern used by Ollama / LM Studio / Cursor

Instead of:

```
Download model
[progress bar]
```

They break the process into **clear stages**:

```
Preparing
Downloading
Verifying
Installing
Ready
```

Even if some stages are instant, it feels much smoother.

Your backend already emits SSE events for pull jobs, which is perfect for this.

---

# UI pattern for local model install

## Model card before install

```
Llama 3.2 3B
Fast local model for everyday assistance

Speed: Fast
Quality: Good
Size: ~2.3 GB

[ Install ]
```

---

## When user clicks Install

The card morphs into a progress component:

```
Llama 3.2 3B
Installing local model

Preparing…
```

Then transitions automatically.

---

## During download

```
Llama 3.2 3B
Downloading 1.4 / 2.3 GB

██████████░░░░░░░░░░
62%

Estimated time: 1m 20s
```

Important UI details:

* show **downloaded bytes**
* show **model size**
* show **estimated time**

People relax when they see numbers.

---

## Verification phase

```
Llama 3.2 3B
Verifying model files…

████████████████████
```

Even if verification takes only a second, showing this stage is psychologically helpful.

---

## Final stage

```
Llama 3.2 3B
Installing runtime configuration…
```

Then:

```
✓ Model ready
```

---

# The subtle trick LM Studio uses

After install completes, they show a **short “Ready” state** before switching the UI.

Example:

```
✓ Model installed
Ready to use locally
```

For about **1 second**.

This prevents the UI from snapping instantly and makes the process feel deliberate and successful.

---

# Another important trick: progressive disclosure of size

Users panic when they see huge downloads.

So don’t show the size too aggressively.

Instead:

Initial card:

```
Size: ~2 GB
```

Only after install begins show:

```
Downloading 450 MB / 2.1 GB
```

---

# Recommended UI states for your install component

You can implement a small state machine.

```
IDLE
STARTING
PREPARING
DOWNLOADING
VERIFYING
INSTALLING
READY
FAILED
```

Each state renders slightly different UI.

---

# Suggested GTK/libadwaita component layout

Something like:

```
AdwPreferencesGroup
 └── ModelInstallRow
       ├── Model name
       ├── Description
       ├── Status label
       ├── Progress bar
       ├── Size / ETA text
       └── Action button
```

Action button states:

```
Install
Installing…
Retry
Remove
```

---

# Make install feel reversible

Another trick from good UX:

After install completes:

```
✓ Installed
[ Remove ]
```

Even if remove just deletes the local model.

Knowing they can undo the download reduces hesitation.

---

# Extremely useful small feature

Show **disk space requirement before install**.

Example:

```
Requires ~2.3 GB disk space
```

Even better:

```
Requires 2.3 GB
You have 86 GB free
```

This prevents mysterious failures.

---

# Live activity indicator

If a model is installing, show a tiny indicator in the **Assistant tab** too.

Example:

```
Installing local model… 62%
```

So users know the app is doing something even if they switch tabs.

---

# Failure UI

Failures happen (network, disk, runtime).

Instead of dumping logs, show:

```
⚠ Model install failed

Network error during download

[ Retry ]   [ Choose another model ]
```

Expandable:

```
Details ▼
```

Which shows the backend error.

---

# Extra trick that reduces abandonment

If download is large (>3GB), show a small message:

```
Large model download
You can continue using CardApp while this installs.
```

This reassures users the app isn't blocked.

---

# Bonus UX trick: recommended badge

Your Caste system is perfect for this.

Show:

```
Recommended for this computer
```

on one model.

Users overwhelmingly choose the recommended option.

---

# Bonus trick: speed labels

Users don't understand parameter counts.

Instead show:

```
Fast
Balanced
More capable
```

Instead of:

```
3B
7B
13B
```

The technical details can be in a tooltip.

---

# Ideal install UI sequence

The whole flow should feel like:

```
Install recommended local AI
        ↓
Preparing
        ↓
Downloading 0 → 100%
        ↓
Verifying
        ↓
Installing
        ↓
✓ Ready
```

Total time perception improves dramatically.

---

# One very important detail

When install finishes:

**automatically select the model as the default local model.**

Do not ask the user.

The next message they send should already use it.

---

# The tiny UX polish that makes apps feel premium

When the install completes:

* progress bar fades out
* checkmark fades in
* status text changes to **Ready**

Animation time: ~200ms.

It sounds trivial but it makes the UI feel much more professional.

---

# The real reason this pattern works

Humans tolerate waiting if they see:

1. **progress**
2. **clear stages**
3. **predictability**

Without those, users assume the app froze.

---

# Your architecture is already perfect for this

You already have:

```
POST /ai/runner/pull
GET /ai/runner/pull/{job_id}
GET /ai/runner/pull/{job_id}/events (SSE)
```

Which is exactly what you need.

The frontend simply maps events to the state machine.
