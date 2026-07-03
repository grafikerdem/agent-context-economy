# Agent Context Economy (ACE)

<p align="center">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Windows%20PowerShell-5.1%2B-blue?style=flat-square&logo=powershell" alt="Windows PowerShell 5.1+">
  <img src="https://img.shields.io/badge/Focus-AI%20Context%20Efficiency-orange?style=flat-square" alt="AI Context Efficiency">
</p>

> Stop wasting model context on noisy terminal dumps, repeated repository discovery, and oversized source reads.

**Agent Context Economy is a methodology and reference implementation for context-efficient AI software development.** It helps agents preserve continuity, orient themselves quickly, discover deliberately, read the smallest useful source region, and validate changes without flooding the conversation.

ACE is designed for Windows repositories and works with coding agents such as Codex, Cursor, Windsurf, Claude Code, and GitHub Copilot. The methodology is tool-agnostic; the included scripts make it immediately usable without Node.js, Python, Rust, WSL, or Docker.

## The Agent Context Economy Stack

| Layer | Purpose | Primary helper |
| :--- | :--- | :--- |
| **Continuity** | Carry forward only the current task, useful searches, and relevant paths. | `session-state.ps1` |
| **Repository Map** | Establish structure, source locations, file counts, and likely entry points. | `repo-map.ps1` |
| **Discovery** | Narrow the repository to a few evidence-backed targets. | `investigate.ps1`, `search.ps1` |
| **Targeted Reading** | Read symbols and local windows instead of entire large files. | `read-symbol.ps1`, `read-window.ps1` |
| **Workflow** | Start compactly and move through bounded, informative steps. | `agent-start.ps1` |
| **Validation** | Keep tests, builds, diffs, and diagnostics useful but compact. | `run-compact.ps1`, `test.ps1` |

[![Agent Context Economy Stack workflow from Continuity through Validation](docs/workflow.svg)](docs/workflow.svg)

Read the full [methodology](docs/methodology.md) for the principles and fallback rules behind the stack.

## Documentation

- [Why Agent Context Economy?](docs/why-agent-context-economy.md) — the recurring context-waste problems and the ACE response.
- [Methodology](docs/methodology.md) — the six-layer behavior model.
- [MCP and discovery-engine integration](docs/mcp-integration.md) — using ACE with repository-aware tools, AST indexes, semantic search, and MCP servers.
- [Source reading economy](docs/source-reading-economy.md) and [command budget](docs/command-budget.md) — operational policies.
- [v0.2.0 release notes](docs/releases/v0.2.0.md) — highlights, compatibility, verification, and publication checklist.
- [Changelog](CHANGELOG.md) — release history and the v0.2.0 scope.

## Benchmark

[![Agent Context Economy benchmark showing reductions in terminal output, source reading, and shell commands](benchmark-results/benchmark.svg)](benchmark-results/benchmark.svg)

| Metric | Conventional workflow | ACE workflow | Reduction |
| :--- | :---: | :---: | :---: |
| Terminal output | 354 lines | **20 lines** | **94%** |
| Source read | 509 lines | **51 lines** | **90%** |
| Shell commands | 7 commands | **2 commands** | **71%** |

This is a reproducible synthetic benchmark; results vary by repository and agent behavior. Run `scripts/powershell/benchmark.ps1` to inspect it locally.

## Toolkit

| Script | What it does |
| :--- | :--- |
| `repo-map.ps1` | Writes a lightweight Markdown repository map to `.agent-context/repo-map.md`. |
| `session-state.ps1` | Maintains small, disposable continuity metadata in `.agent-context/session-state.json`. |
| `agent-start.ps1` | Prints a compact briefing from the map and session state when available. |
| `investigate.ps1` | Batches related searches into one structured discovery report. |
| `search.ps1` | Summarizes a repository search without dumping every match. |
| `find-in-file.ps1` | Finds an exact value within a known file. |
| `read-symbol.ps1` | Reads a named class, function, method, or component with bounded context. |
| `read-window.ps1` | Reads a precise line window. |
| `run-compact.ps1` | Preserves useful diagnostics while compacting noisy command output. |
| `diff-summary.ps1` / `diff-file.ps1` | Provides focused Git change summaries. |
| `smoke-test.ps1` | Verifies the PowerShell helpers with lightweight local fixtures. |

Scripts inspect the repository read-only except for generated data under `.agent-context` or benchmark output under `benchmark-results`.

## Quick Start

From the repository where ACE is installed:

```powershell
.\scripts\powershell\setup-ai-scripts.ps1
.\scripts\powershell\smoke-test.ps1
.\scripts\powershell\repo-map.ps1
.\scripts\powershell\session-state.ps1 set-task -Value "Describe the current task"
.\scripts\powershell\agent-start.ps1
```

Copy the relevant policies from [examples/AGENTS.example.md](examples/AGENTS.example.md) into your project-level `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, or equivalent instruction file.

The preferred workflow is:

```text
repo-map -> investigate -> read-symbol -> read-window -> run-compact
```

It is a decision path, not mandatory ceremony. Skip steps when the target is known, and use bounded raw exploration when a helper cannot express the query.

For noisy validation commands, keep the actionable diagnostics without loading the full log:

```powershell
.\scripts\powershell\run-compact.ps1 -Command "php artisan test" -MaxLines 250
```

## Works Alongside Existing Repository Intelligence

ACE complements AST indexes, language servers, semantic search, code graphs, and MCP repository tools. Those systems can provide richer symbol and relationship data. ACE provides the surrounding discipline: establish continuity, map before exploring, make focused queries, read selectively, and validate without unnecessary output.

Use the strongest repository intelligence available. ACE is the workflow layer that keeps its results economical.

Discovery engines find context. ACE governs how that context is acquired, consumed, carried forward, and validated.

## Design Constraints

- Windows PowerShell compatible
- no external dependencies
- UTF-8 output for generated files
- small, disposable state with no source contents or secrets
- read-only repository inspection, aside from `.agent-context` and `benchmark-results`

## Philosophy

The goal is not to blind the agent. The goal is to help it read a repository like a careful developer: summarize first, choose the exact target, read the smallest meaningful context, and expand only when evidence requires it.

See [docs/philosophy.md](docs/philosophy.md), [docs/source-reading-economy.md](docs/source-reading-economy.md), and [docs/command-budget.md](docs/command-budget.md).

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
