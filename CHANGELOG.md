# Changelog

All notable changes to Agent Context Economy are documented in this file.

## [0.2.0] - 2026-07-03

### Added

- The six-layer Agent Context Economy Stack: Continuity, Repository Map, Discovery, Targeted Reading, Workflow, and Validation.
- `repo-map.ps1` for lightweight Markdown repository maps.
- `session-state.ps1` for small, disposable task continuity metadata.
- `agent-start.ps1` for compact startup briefings.
- Methodology, “Why ACE?”, and MCP/discovery-engine integration guides.
- A workflow SVG that explains the complete ACE Stack.
- Generated benchmark SVG output under `benchmark-results`.
- Smoke-test coverage for repository maps, session state, and startup briefings.

### Changed

- Repositioned ACE from a collection of helper scripts to a methodology and reference implementation for context-efficient AI software development.
- Expanded `AGENTS.example.md` with startup, raw-exploration fallback, and approval-economy policies.
- Updated the README with the stack, generated benchmark artefacts, integration positioning, and documentation paths.

### Compatibility

- Windows PowerShell 5.1 or later.
- No Node.js, Python, Rust, WSL, Docker, or external package dependencies.
- Generated files use explicit UTF-8 encoding.

## [0.1.1] - 2026-07-02

- Added reproducible synthetic benchmark output and documentation improvements.

## [0.1.0]

- Introduced the initial PowerShell helpers for compact command output, targeted source reading, focused search, and diff inspection.
