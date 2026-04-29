# Git Sync Wizard Design

## Status
Draft design for GTK desktop frontend implementation.

## Goals
- Provide a simple setup path for users who do not know Git.
- Provide fast setup for users who already know Git.
- Keep project sync configuration per-project only.

## Non-Goals
- No global/default remote configuration.
- No multi-project scope selection.
- No one-big-repo model.

## Project Model
- Each project has exactly one Git remote (optional).
- Sync configuration applies to the currently selected project only.

## Entry Options
1. Guided (GitHub)
2. Provider (advanced)
3. Paste URL

## Flow 1: Guided (GitHub)
Audience: users with little/no Git knowledge.

### Screen 1: Basic details
- Username or organization
- Repository name (default: project name slug)
- Transport: HTTPS (default) or SSH

### Screen 2: Auth help
- If HTTPS: show token setup instructions link.
- If SSH: show key instructions and detect whether a local key exists.

### Screen 3: Confirm
- Show resulting remote URL.
- Show project name and project id.
- Warning line:
  - Encrypted projects: "Remote stores encrypted card blobs."
  - Shared/plain projects: "Do not store sensitive content in shared/plain projects."
- Actions:
  - Back
  - Save and Test

## Flow 2: Provider (advanced)
Audience: users who know Git and want structured setup.

### Screen 1: Provider + transport
- Provider dropdown (from backend git providers catalog)
- Transport dropdown (provider-supported transports only)

### Screen 2: Namespace + repository
- Owner/group/org
- Repository name (default: project name slug)
- Optional branch (default: main)
- Live URL preview

### Screen 3: Confirm
- Editable final URL
- Save and Test

## Flow 3: Paste URL
Audience: users who already have a remote URL.

### Single screen
- Remote URL input
- Optional branch (default: main)
- Non-blocking provider detection (if recognizable)
- Save and Test

## Save and Test behavior
After user confirms, frontend does:
1. PATCH current project with `git_remote_url`.
2. Trigger remote test/pull behavior.
3. Show result dialog with:
   - project_id
   - remote_configured
   - pull_status (`succeeded` / `failed` / `not_attempted`)
   - remote_error
   - pull_error

## Validation Rules
- Remote URL must be non-empty and valid format.
- Owner/repo required for Guided and Provider flows.
- Branch optional; default `main`.
- HTTPS/SSH hints shown based on chosen transport.

## Error Handling
Common user-facing failures:
- Remote already exists/in use.
- Authentication failure (token/key missing or invalid).
- Network unavailable.
- Pull conflict or non-fast-forward restrictions.

Dialog should always explain:
- What succeeded (config saved or not).
- What failed (remote setup vs pull).
- Next action (retry, edit URL/auth, cancel).

## Backend Touchpoints
Current endpoints used:
- `GET /git-providers.json` (provider metadata)
- `PATCH /projects/{project_id}` (`git_remote_url`)
- Existing per-project sync/test behavior (current backend implementation)

## Implementation Order
1. Wizard shell + mode selection UI.
2. Paste URL path end-to-end (fastest path).
3. Guided (GitHub) path.
4. Provider (advanced) path.
5. Polished result dialog + retry actions.
