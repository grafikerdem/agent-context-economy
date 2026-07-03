# Why Agent Context Economy?

AI coding agents can search, read, edit, and validate software quickly. The limiting factor is often not access to information, but how much irrelevant information enters the working context before a useful decision is made.

Agent Context Economy (ACE) is a behavior model for that problem. It asks an agent to acquire context in layers, preserve only useful continuity, and expand its view when evidence requires it. The included PowerShell scripts are a reference implementation of that model.

## Recurring Context-Waste Patterns

### Problem 1: The agent repeatedly rediscovers the repository

New turns and handoffs often repeat the same directory scans, searches, and file selection. This spends commands and context without adding understanding.

**ACE layer: Continuity**

Keep a small, disposable record of the current task, relevant paths, and useful searches. Do not store source contents, logs, or secrets.

### Problem 2: Exploration starts without orientation

An agent searches broadly because it does not know the repository shape, common source locations, or likely entry points.

**ACE layer: Repository Map**

Create a lightweight structural map before deep discovery. The map is a hint, not a replacement for repository instructions or source reading.

### Problem 3: Discovery becomes a chain of tiny searches

Repeated generic searches create approval friction and return overlapping results. The agent collects matches without narrowing the problem.

**ACE layer: Discovery**

Batch related, exact queries and choose a small number of likely files. Discovery should reduce uncertainty, not produce a repository transcript.

### Problem 4: Entire files are read for one symbol

Large controllers, components, services, or test files are often loaded when only one method or local relationship matters.

**ACE layer: Targeted Reading**

Read the named symbol first, then one nearby window if necessary. Expand only when the missing context can be stated clearly.

### Problem 5: Tools dictate the process

Agents may have excellent AST indexes, semantic search, code graphs, or MCP tools but still use them without a bounded investigation strategy.

**ACE layer: Workflow**

Use the strongest available navigation capability inside a consistent path: orient, discover, select, read, act, and validate. The methodology remains stable when the underlying tool changes.

### Problem 6: Validation floods the context

Builds and test suites can emit hundreds of successful or repetitive lines while the useful failure evidence occupies only a small fraction of the output.

**ACE layer: Validation**

Run the narrowest relevant check and retain the failure name, source location, diagnostic detail, and final status. Broaden validation when risk requires it.

## The Core Mapping

| Context-waste problem | ACE response |
| :--- | :--- |
| Repeated repository rediscovery | Continuity |
| No structural orientation | Repository Map |
| Search-command chains | Discovery |
| Whole-file source dumps | Targeted Reading |
| Tool-driven, inconsistent behavior | Workflow |
| Massive build and test output | Validation |

## What ACE Is Not

ACE is not a code index, vector database, language server, or model-specific prompt framework. It does not compete with tools that find symbols or rank relevant code.

ACE governs how repository context is acquired, consumed, carried forward, and validated. Discovery engines find context; ACE keeps the surrounding workflow economical.

## The Product Evolution

```text
v0.1  PowerShell helper scripts
  ->  v0.2  workflow toolkit
  ->  methodology and reference implementation for context-efficient AI software development
```

The scripts demonstrate the methodology on Windows PowerShell without external dependencies. Other implementations can use different shells, IDE APIs, AST indexes, semantic search systems, or MCP servers while preserving the same behavior model.
