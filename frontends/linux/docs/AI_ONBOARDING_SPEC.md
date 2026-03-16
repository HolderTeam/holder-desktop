# AI Onboarding and Settings Specification

This document outlines the implementation plan for a guided AI onboarding experience and a refactored AI settings/status interface in the Holder Linux frontend.

## Goals

*   **Zero-Config to Hero:** Guide users from an empty state to a working AI setup in under a minute.
*   **Local-First, Cloud-Enhanced:** Prioritize private local models while making cloud integration (especially Gemini) seamless.
*   **Human-Friendly Language:** Replace technical jargon (backend, router, provider) with intent-based language (Fast, Private, Stronger).
*   **Visual Progress:** Provide clear, animated feedback during model downloads and connection tests.

---

## 1. Guided Onboarding Flow

Onboarding will be a stateful 5-step flow displayed in the **Assistant** tab when AI is not yet configured.

### Step 1: Device Detection & Recommendation
*   **Action:** Query `/ai/capabilities` and `/ai/status`.
*   **UI:** Show a "Computer Class" summary (from Caste) and two primary recommendation cards:
    *   **Card A (Local):** "Use AI on this computer" (Recommended if hardware allows).
    *   **Card B (Cloud):** "Connect a cloud provider" (Gemini highlighted).
*   **Logic:** If local runner is unavailable, disable Card A and explain why.

### Step 2: Local Model Selection
*   **Action:** Fetch models from `/ai/providers/catalog` filtered by the `recommended_install` list from capabilities.
*   **UI:** 
    *   Top: One "Recommended" model card (e.g., Llama 3.2 3B).
    *   Below: 3-5 other suitable models with speed/quality tags.
*   **Interaction:** Clicking "Install" initiates `POST /ai/runner/pull`.

### Step 3: Cloud Provider Setup (Gemini Focus)
*   **UI:** 
    *   "Connect Gemini" card with "Get API Key" link to [Google AI Studio](https://aistudio.google.com/app/apikey).
    *   Input field for API Key.
    *   "Test Connection" button.
*   **Test Connection Logic:** Perform a minimal request to verify the key before saving.

### Step 4: Default Behavior (Routing)
*   **Options (Humanized):**
    *   **Prefer Local:** "Use private models on this computer when possible."
    *   **Prefer Cloud:** "Use connected cloud APIs for better reasoning."
    *   **Automatic:** "Let Holder choose based on task and availability."
    *   **Ask Each Time:** Show a picker before sending.
*   **Backend Map:** Maps to global `router_model` and `provider_settings`.

### Step 5: Ready State
*   **UI:** Summary of setup: "Local: Llama 3.2 | Cloud: Gemini | Mode: Prefer Local".
*   **CTA:** "Start Chatting".

---

## 2. Refactored AI Panel (Tabs)

The existing three tabs will be enhanced with modern `libadwaita` components.

### Tab A: Assistant (Everyday Use)
*   **Route Badge:** A clickable chip above the composer (e.g., `Local · Llama 3.2`).
*   **Route Picker:** Popover to override the model/provider for the current thread.
*   **Empty State:** Helpful prompts like "Summarize this card" or "Plan a project" instead of a blank screen.
*   **Run Metadata:** Small text above responses indicating which model was used and if a fallback occurred.

### Tab B: Status (Operational View)
Use `Adw.PreferencesGroup` and `Adw.ActionRow` for:
1.  **System Health:** Local runner status, active runs, active pulls.
2.  **Local Models:** List of installed models with "Remove" buttons.
3.  **Cloud Providers:** List of configured providers with Enable/Disable toggles and Edit (Key) actions.
4.  **Recent Activity:** Mini log of the last 5 runs (Status, Model, Time).

### Tab C: Catalog (Management & Discovery)
*   **Recommended Section:** Large cards for the best matches for this machine.
*   **Model List:** Categorized by Quality (Basic, Good, Strong) and Speed (Fast, Balanced).
*   **Provider List:** All supported cloud providers (OpenAI, Anthropic, etc.) with setup links.

---

## 3. Visual Perception: The "App Install" Pattern

Model pulls should not be simple progress bars. They must follow the "App Install" stages:
1.  **Preparing:** Initializing pull job.
2.  **Downloading:** Showing `X.X GB / Y.Y GB` and estimated time.
3.  **Verifying:** Checksum validation (even if fast).
4.  **Ready:** Finalizing configuration.

---

## 4. Implementation Checklist

### Phase 1: Models & State
- [ ] Define `AiOnboardingState` in `app_state.vala`.
- [ ] Add `CloudProviderStatus` enum to `models.vala` (Not Configured, Configured, Enabled, Error).
- [ ] Update `AiStatusInfo` to include more granular provider state if possible.

### Phase 2: Components (Views)
- [ ] Create `AiModelCard` widget (Adw.Bin or Gtk.Box).
- [ ] Create `AiProviderRow` widget (Adw.ActionRow).
- [ ] Create `AiRouteBadge` widget (Gtk.Button with custom styling).
- [ ] Create `AiPullProgressWidget` using the "App Install" pattern.

### Phase 3: Controllers
- [ ] Refactor `AiRunController` to handle connection testing.
- [ ] Implement `AiOnboardingController` to manage the 5-step state machine.
- [ ] Implement SSE listener for detailed pull events (Downloaded bytes, etc.).

### Phase 4: Integration
- [ ] Update `AiPanel` to switch between `AiOnboardingView` and the standard 3-tab view.
- [ ] Connect "Test Connection" to the backend.
- [ ] Ensure "Prefer Local" actually sets the correct router config in the backend.

---

## 5. API Mapping

| UI Action | Backend Endpoint |
| :--- | :--- |
| Check Capabilities | `GET /ai/capabilities` |
| Check Status | `GET /ai/status` |
| Get Catalog | `GET /ai/providers/catalog` |
| Start Pull | `POST /ai/runner/pull` |
| Pull Progress | `GET /ai/runner/pull/{id}/events` (SSE) |
| Save Credentials | `PUT /ai/providers/credentials` |
| Toggle Provider | `PUT /ai/providers/settings` |
| Set Routing | `PUT /ai/router/config` |
| Run Chat | `POST /ai/runs` (SSE) |
