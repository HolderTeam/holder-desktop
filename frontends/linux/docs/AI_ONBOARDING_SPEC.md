# AI Onboarding and Configuration Spec (Codebase-Aligned)

This document is the frontend-facing spec for AI onboarding/config in the Linux client, based on the current `holder-desktop/frontends/linux` and `holder-daemon` code.

It replaces earlier aspirational notes that did not match implementation.

## 1) Current Baseline (What Exists Today)

### 1.1 Panel and tabs

- AI UI is in `src/views/ai_panel.vala`.
- It has 3 tabs:
  - `Assistant`
  - `Status`
  - `Catalog`
- Catalog view implementation is `src/views/ai_panel/catalog.vala`.
- Panel wiring/orchestration is `src/controllers/ai_panel_event_orchestrator.vala`.

### 1.2 Controller behavior

- Main runtime controller: `src/controllers/ai_run.vala`.
- `AiRunController` currently handles:
  - status refresh (`/ai/capabilities`, `/ai/status`)
  - local model pull start (`POST /ai/runner/pull`)
  - AI run streaming (`POST /ai/runs` SSE)
  - thread creation and selection integration
- When AI panel is visible, status polling runs every 2s while pull jobs are active.
- Pull progress detail is not consumed from pull SSE endpoint; status polling is used instead.

### 1.3 API client surface currently used by AI panel

Defined in `src/services/api_client/ai.vala` and `src/services/api_client/ai_stream.vala`:

- `GET /ai/capabilities` (`project_id` optional query)
- `GET /ai/status`
- `POST /ai/runner/pull`
- `GET /ai/threads`
- `POST /ai/threads`
- `POST /ai/runs` (SSE stream)
- `GET /ai_catalog.json` (static, unwrapped JSON)

### 1.4 Data models currently in frontend

`src/models/models.vala`:

- `AiCapabilitiesInfo`
  - runner availability/error/version
  - machine caste name
  - installed model names
  - `recommended_install` (list of tags)
- `AiStatusInfo`
  - active runs
  - active pull jobs
  - cloud configured provider count
  - pull jobs summarized as display strings
- `AiCatalogProvider`
  - id, display name, enabled/configured, setup/docs URLs

### 1.5 Catalog data source in frontend

Current catalog tab reads from static catalog:

- `GET /ai_catalog.json` (not `/ai/providers/catalog`)

Parser (`ApiParsersAi.parse_ai_provider_catalog`) currently reads from:

- `models.provider_defaults`

This means catalog UI currently shows provider-default metadata, not runtime DB-resolved provider state.

## 2) Backend Capability Surface Relevant to Onboarding

The daemon supports more than frontend currently uses:

- Runtime/capabilities:
  - `GET /ai/capabilities`
  - `GET /ai/status`
  - `POST /ai/runner/retry`
- Local pull jobs:
  - `POST /ai/runner/pull`
  - `GET /ai/runner/pull/{job_id}`
  - `GET /ai/runner/pull/{job_id}/events` (SSE)
- Provider runtime config:
  - `GET /ai/providers/catalog`
  - `GET/PUT/DELETE /ai/providers/settings...`
  - `GET/PUT/DELETE /ai/providers/credentials...`
- Router config:
  - `GET /ai/router/config`
  - `PUT /ai/router/config`
- Runs/history:
  - `POST /ai/runs` (SSE)
  - `GET /ai/runs`, `GET /ai/runs/{id}`, `GET /ai/runs/{id}/events`

Frontend currently uses only a subset of this.

## 3) Gaps (Current Frontend vs Backend Support)

### 3.1 Not implemented in frontend yet

- No UI for provider credentials (`/ai/providers/credentials`).
- No UI for provider enable/disable (`/ai/providers/settings`).
- No UI for router preference (`/ai/router/config`).
- No explicit connection test workflow for cloud provider keys.
- No use of pull-job SSE detail; no staged install UX from backend events.
- No run history UI (`/ai/runs` query endpoints).

### 3.2 Data limitations in current frontend models

- `AiCapabilitiesInfo` does not retain full router config payload.
- `AiStatusInfo` does not retain cloud provider list details (only count + pull summary text).
- Catalog parser is tied to static `provider_defaults`, not runtime provider state.

## 4) Onboarding Rewrite Target

### 4.1 Product intent

- Fast first-time setup for local and/or cloud.
- Explicit, understandable configuration state.
- Keep local-first behavior clear, but expose cloud path as first-class option.

### 4.2 Technical intent

- Move onboarding/config logic into controllers/services (testable), keep views mostly rendering.
- Use backend runtime endpoints for mutable state (`/ai/providers/*`, `/ai/router/config`), not static-only catalog.
- Keep static `/ai_catalog.json` as descriptive source (labels/docs/examples), not source of runtime truth.

## 5) Implementation Plan (Concrete)

### Phase A: API client + parser expansion

- Add API methods for:
  - `GET /ai/providers/catalog`
  - `GET/PUT/DELETE /ai/providers/settings...`
  - `GET/PUT/DELETE /ai/providers/credentials...`
  - `GET/PUT /ai/router/config`
  - `POST /ai/runner/retry`
- Add parser models for:
  - provider catalog runtime shape (`data.providers[]`)
  - provider credentials/settings payloads
  - router config payload (`global/project/effective`)
- Keep existing static `list_ai_provider_catalog()` path for read-only catalog text where useful.

### Phase B: onboarding state model + controller

- Add `AiOnboardingState` to represent:
  - runner status snapshot
  - local recommendations/install state
  - cloud provider credential/config state
  - router preference state
- Add `AiOnboardingController` to orchestrate:
  - load initial state
  - update provider key
  - toggle provider enabled
  - set router preference
  - start/retry local pull

### Phase C: panel integration

- Keep 3 tabs, but redefine responsibilities:
  - `Assistant`: prompt/run thread use
  - `Status`: runtime + pulls + quick actions
  - `Catalog`: model/provider discovery/help
- Add onboarding entry UI when AI is unconfigured:
  - shown inside AI panel (not project toolbox)
  - action-driven by `AiOnboardingController`

### Phase D: richer pull/install UX

- Integrate pull events stream (`/ai/runner/pull/{id}/events`) in controller.
- Render stage/progress in status/onboarding UI.
- Retain polling fallback if SSE stream disconnects.

### Phase E: run metadata/history

- Expose selected model/provider and fallback events in Assistant output more clearly.
- Optional: add recent run history using `/ai/runs` list/get routes.

## 6) Endpoint Mapping for Rewrite

| Frontend concern | Endpoint(s) |
| --- | --- |
| Capabilities snapshot | `GET /ai/capabilities` |
| Runtime snapshot | `GET /ai/status` |
| Retry local runner probe | `POST /ai/runner/retry` |
| Start local model pull | `POST /ai/runner/pull` |
| Pull progress | `GET /ai/runner/pull/{job_id}` + `/events` |
| Runtime provider catalog | `GET /ai/providers/catalog` |
| Save/remove provider key | `PUT/DELETE /ai/providers/credentials...` |
| Enable/disable provider | `PUT/DELETE /ai/providers/settings...` |
| Read/write router preference | `GET/PUT /ai/router/config` |
| Run AI stream | `POST /ai/runs` (SSE) |
| Static descriptive catalog | `GET /ai_catalog.json` |

## 7) Non-Goals for This Rewrite

- Reworking backend AI routing logic.
- Replacing thread/message storage model.
- Moving AI into project toolbox (AI panel remains global UI region).

## 8) Acceptance Criteria

- User can configure at least one cloud provider key fully from frontend.
- User can enable/disable providers from frontend.
- User can set router preference from frontend.
- User can install local model and see meaningful pull progress.
- Assistant tab still supports current prompt/thread flow with no regression.
- New controller-level logic has unit tests (views remain thinner).
