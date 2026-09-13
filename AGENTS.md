# Coding-agent instructions

Treat the current code, tests, backend API contract, and explicitly referenced active task plans as authoritative. Other planning or design documents may be stale.

Holder Desktop is a thin GTK4/libadwaita client. Storage, indexing, search, Git operations, AI execution, and reusable domain logic belong in the backend/core rather than the frontend.

Prefer native GTK/libadwaita behaviour and preserve the project's supported runtime baseline.

Do not infer the current backend API from old planning documents. Use the current OpenAPI contract and implementation.

Do not perform unrelated architectural cleanup while implementing a focused task.
