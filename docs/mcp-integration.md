# MCP and Discovery Engine Integration

Agent Context Economy is discovery-engine independent. It can work with MCP servers, AST indexes, semantic search, code graphs, language servers, or plain repository search.

The integration boundary is simple:

```text
Discovery engine -> ACE workflow -> Validation
```

Discovery engines find and rank context. ACE governs when to query them, how much of their output to consume, what continuity metadata to retain, and how to validate the resulting change.

## Discovery Options

Depending on the environment, discovery may be provided by tools such as:

| Discovery capability | Best use inside ACE |
| :--- | :--- |
| Octocode or another repository-aware MCP server | Cross-file discovery, repository structure, and focused code retrieval. |
| Serena or another symbol-aware coding tool | Symbol lookup, references, and targeted navigation. |
| Sourcegraph or another code intelligence platform | Large-repository search and relationship discovery. |
| Language server or AST index | Definitions, references, call relationships, and type-aware navigation. |
| Semantic search | Locating conceptually related implementation when exact names are unknown. |
| `ripgrep` or ACE PowerShell helpers | Exact text discovery and a dependency-free fallback. |

These are examples, not required dependencies or endorsements. Use the strongest capability already available in the coding environment.

## Integration Workflow

### 1. Continuity

Recover the current task, previously selected paths, and useful search terms. Do not copy full MCP responses into session state.

### 2. Repository Map

Use an existing repository index or `repo-map.ps1` to establish the project shape. Read repository-level instructions before acting.

### 3. Discovery

Ask the discovery engine a bounded question:

- Where is the named symbol defined?
- Which files implement this route or feature?
- What calls this method?
- Which tests cover this behavior?

Prefer one query that returns ranked files or symbols over a chain of loosely related searches.

### 4. Targeted Reading

Read only the selected symbol, definition, reference group, or local source window. An MCP tool may perform this step directly; ACE scripts are a fallback when it does not.

### 5. Workflow

Make the smallest justified change. Record only the few paths or searches that would prevent rediscovery during a handoff.

### 6. Validation

Run the narrowest relevant test, type check, build, or static analysis. Compact noisy output while preserving actionable diagnostics.

## Example Tool-Neutral Sequence

```text
1. Read repository instructions.
2. Load the ACE startup briefing.
3. Ask the available discovery engine for the feature's definitions and tests.
4. Select the top one to three relevant files.
5. Read exact symbols or bounded windows.
6. Implement the focused change.
7. Run compact, targeted validation.
8. Broaden only if evidence or risk requires it.
```

## Output Discipline for MCP Tools

MCP access does not make unlimited context free. When a tool offers filters or limits:

- constrain the repository path or module,
- request definitions or references for exact symbols,
- cap result counts,
- prefer summaries with stable file and line references,
- fetch source bodies only for selected results,
- avoid retaining complete tool transcripts in continuity state.

## Fallback Policy

If an MCP server, semantic index, or AST tool is unavailable or cannot express the query, fall back to bounded repository search with `investigate.ps1`, `search.ps1`, or `ripgrep`.

Raw repository exploration should be treated as a fallback, not the default workflow. State what information is missing, constrain the fallback query, summarize the result, and return to targeted reading once the likely implementation surface is known.

## Integration Principle

> Use the best discovery engine available. Keep the ACE behavior model constant.

This lets a team change editors, models, MCP servers, or indexing systems without abandoning its context-efficiency discipline.
