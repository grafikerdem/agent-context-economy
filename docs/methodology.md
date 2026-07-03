# Agent Context Economy Methodology

Agent Context Economy (ACE) is a lightweight methodology and toolkit for reducing context waste in AI-assisted software work. It does not try to replace repository understanding. It gives agents a repeatable way to acquire that understanding with less noise.

## The Agent Context Economy Stack

The stack has six layers. Each layer answers a different question before more context is loaded.

| Layer | Question | ACE practice |
| :--- | :--- | :--- |
| Continuity | What was already learned or decided? | Keep a small, disposable task state with `session-state.ps1`. |
| Repository Map | What kind of repository is this? | Generate a lightweight structural overview with `repo-map.ps1`. |
| Discovery | Where is the likely implementation surface? | Batch focused searches with `investigate.ps1` or use `search.ps1`. |
| Targeted Reading | What is the smallest useful source context? | Prefer `read-symbol.ps1`, then `read-window.ps1`; use `find-in-file.ps1` inside known files. |
| Workflow | What should happen next? | Start from a compact briefing, work in bounded steps, and record only useful continuity metadata. |
| Validation | Did the change work, and can the result be read cheaply? | Run the narrowest relevant check through `run-compact.ps1` or `test.ps1`. |

### 1. Continuity

Continuity prevents every agent turn or handoff from rediscovering the same task, files, and searches. The state should remain intentionally small: a short task statement, a bounded list of relevant file paths, and a bounded list of useful search terms.

Continuity state is disposable. It is not a project database, an audit log, or a place for source text, command output, credentials, tokens, or other secrets.

### 2. Repository Map

A repository map provides orientation before exploration. It summarizes the top-level layout, common source locations, file counts, and likely entry points. It is a hint, not an index and not a substitute for reading the repository's own instructions.

Regenerate the map when the repository structure changes materially. Do not regenerate it before every small task.

### 3. Discovery

Discovery narrows the problem from “the repository” to a few likely files. Prefer one batched investigation using exact domain terms, symbols, routes, configuration keys, or error fragments. Avoid long chains of generic searches.

If structured discovery tools do not support the repository or query, use a bounded raw search and summarize the result before continuing.

### 4. Targeted Reading

Once likely files are known, read the smallest meaningful unit:

1. a named symbol when possible,
2. one local line window when surrounding context is needed,
3. a whole file only when it is small or its complete structure is necessary.

Targeted reading is not about hiding context. It is about delaying irrelevant context until evidence shows it is needed.

### 5. Workflow

The preferred workflow is:

```text
repo-map -> investigate -> read-symbol -> read-window -> run-compact
```

This is a decision path, not a requirement to invoke every tool. Skip steps when the target is already known. Fall back to raw exploration when an ACE helper cannot express the necessary query, but keep the search bounded and explain why the fallback is needed.

### 6. Validation

Validation should match the risk and scope of the change. Start with the narrowest relevant test, type check, build, or static check. Compact noisy output while retaining failure names, source locations, and diagnostic details.

Escalate to broader validation when the targeted result is insufficient or the change has wider effects. Context economy should reduce noise, never weaken correctness.

Every reduction should be explainable. Compact output should preserve enough provenance for a reviewer to understand why this context was shown, what was omitted, and which smallest next step can recover missing evidence.

## Relationship to Other Repository Tools

ACE complements AST indexes, language servers, semantic search, and MCP-based repository tools. Those systems can identify symbols and relationships more precisely; ACE supplies the operating discipline around them: orient first, query deliberately, read selectively, preserve small continuity state, and validate with compact output.

Use the best available navigation capability. The methodology matters more than whether a particular helper script performs the lookup.

Raw repository exploration should be treated as a fallback, not the default workflow.
