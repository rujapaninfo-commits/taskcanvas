# TaskCanvas Design

## Product modes

### Widget

- Goal: glanceable tree view
- Default: Google order, subtasks expanded
- Allowed: read only in this scaffold
- Avoided: sorting, detailed editing

### Menu bar

- Goal: quick add and quick complete
- Default: primary list only
- Allowed: add task, toggle completion, refresh
- Avoided: sorting and list management

### Full app

- Goal: full workspace
- Default: split view with list picker, task column, inspector
- Allowed: refresh, browse lists, add tasks, complete tasks
- Next: reorder, task detail editing, list management

## Data flow

1. App stores OAuth client ID and tokens in shared storage.
2. App fetches Google task lists and tasks through Tasks API.
3. Shared snapshot is written to the app group defaults.
4. Widget reads the snapshot and renders a compact tree.

## Current gaps

- Requires a real Google OAuth Client ID from Google Cloud
- Requires Xcode signing and App Group setup
- Sorting/editing beyond add + complete is not implemented yet
- Widget interactions are display-only for now
